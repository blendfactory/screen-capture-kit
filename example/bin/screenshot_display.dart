import 'dart:io';

import 'package:screen_capture_kit/screen_capture_kit.dart';

/// Captures one display to a PNG file in the given output directory.
///
/// Run from the example package root (see example README for the exact
/// command).
///
/// Optional flag `--display <n>` selects the n-th display (1-based) without
/// interactive prompts.
Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed == null) {
    _printUsage();
    exitCode = 64; // EX_USAGE
    return;
  }

  if (!Platform.isMacOS) {
    stderr.writeln('This tool only runs on macOS.');
    exitCode = 2;
    return;
  }

  final kit = ScreenCaptureKit();
  FilterId? filter;

  try {
    final content = await kit.getShareableContent();
    final displays = content.displays;
    if (displays.isEmpty) {
      stderr.writeln('No displays available for capture.');
      exitCode = 1;
      return;
    }

    final index = _selectDisplayIndex(displays, parsed.displayOneBased);
    if (index == null) {
      exitCode = 64;
      return;
    }

    final display = displays[index];
    stdout.writeln(
      'Capturing display ${index + 1}/${displays.length}: '
      'id=${display.displayId.value}, ${display.width}x${display.height}',
    );

    filter = await kit.createDisplayFilter(display);
    final image = await kit.captureScreenshot(
      filter,
      frameSize: FrameSize(width: display.width, height: display.height),
      captureResolution: parsed.captureResolution,
    );
    final file = _writePng(parsed.outputDir, display, image);
    stdout.writeln('Wrote ${file.lengthSync()} bytes to ${file.path}');
  } on ScreenCaptureKitException catch (e) {
    stderr.writeln('ScreenCaptureKit error: $e');
    exitCode = 1;
  } on UnsupportedError catch (e) {
    stderr.writeln('Unsupported: $e');
    exitCode = 2;
  } on Object catch (e, st) {
    stderr.writeln('Error: $e\n$st');
    exitCode = 1;
  } finally {
    if (filter != null) {
      kit.releaseFilter(filter);
    }
  }
}

class _ParsedArgs {
  const _ParsedArgs({
    required this.outputDir,
    this.displayOneBased,
    this.captureResolution = CaptureResolution.automatic,
  });

  final Directory outputDir;

  /// 1-based display index when provided; otherwise interactive selection.
  final int? displayOneBased;

  final CaptureResolution captureResolution;
}

_ParsedArgs? _parseArgs(List<String> args) {
  Directory? outDir;
  int? displayOneBased;
  var quality = CaptureResolution.automatic;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--help' || a == '-h') {
      return null;
    }
    if (a == '--out' || a == '-o') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      outDir = Directory(args[++i]);
      continue;
    }
    if (a == '--display' || a == '-d') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      displayOneBased = int.tryParse(args[++i]);
      if (displayOneBased == null || displayOneBased < 1) {
        stderr.writeln('Invalid --display value (use a positive integer).');
        return null;
      }
      continue;
    }
    if (a == '--quality' || a == '-q') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      final raw = args[++i].toLowerCase();
      if (raw == 'automatic' || raw == 'auto') {
        quality = CaptureResolution.automatic;
      } else if (raw == 'best') {
        quality = CaptureResolution.best;
      } else if (raw == 'nominal') {
        quality = CaptureResolution.nominal;
      } else {
        stderr.writeln(
          'Invalid --quality (use automatic, best, or nominal).',
        );
        return null;
      }
      continue;
    }
    if (a.startsWith('-')) {
      stderr.writeln('Unknown option: $a');
      return null;
    }
    if (outDir == null) {
      outDir = Directory(a);
    } else {
      stderr.writeln('Unexpected argument: $a');
      return null;
    }
  }

  if (outDir == null) {
    stderr.writeln('Output directory is required.');
    return null;
  }

  return _ParsedArgs(
    outputDir: outDir,
    displayOneBased: displayOneBased,
    captureResolution: quality,
  );
}

void _printUsage() {
  stderr.writeln(
    'Capture a display screenshot as PNG.\n'
    '\n'
    'Usage:\n'
    '  dart run bin/screenshot_display.dart --out <dir> '
    '[--display <n>]\n'
    '  dart run bin/screenshot_display.dart <dir> '
    '[--display <n>]\n'
    '\n'
    'Options:\n'
    '  --out, -o <dir>     Directory for the PNG '
    '(created if missing)\n'
    '  --display, -d <n>   1-based display index '
    '(omit to choose interactively)\n'
    '  --quality, -q <m>   automatic|best|nominal '
    '(SCStreamConfiguration.captureResolution; default automatic)\n'
    '  --help, -h          Show this help\n'
    '\n'
    'Requires macOS 14+ for captureScreenshot. '
    'Screen Recording permission.',
  );
}

int? _selectDisplayIndex(
  List<Display> displays,
  int? displayOneBased,
) {
  if (displayOneBased != null) {
    if (displayOneBased > displays.length) {
      stderr.writeln(
        'Display $displayOneBased not found '
        '(only ${displays.length} display(s)).',
      );
      return null;
    }
    return displayOneBased - 1;
  }

  stdout.writeln('Displays:');
  for (var i = 0; i < displays.length; i++) {
    final d = displays[i];
    stdout.writeln(
      '  ${i + 1}) id=${d.displayId.value}  ${d.width}x${d.height}',
    );
  }
  stdout.write('Select display [1-${displays.length}]: ');
  final line = stdin.readLineSync()?.trim();
  final n = int.tryParse(line ?? '');
  if (n == null || n < 1 || n > displays.length) {
    stderr.writeln('Invalid selection.');
    return null;
  }
  return n - 1;
}

File _writePng(
  Directory outputDir,
  Display display,
  CapturedImage image,
) {
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        ':',
        '-',
      );
  final name =
      'display_${display.displayId.value}_${image.width}x${image.height}_'
      '$timestamp.png';
  final file = File('${outputDir.path}/$name');
  file.writeAsBytesSync(image.pngData, flush: true);
  return file;
}
