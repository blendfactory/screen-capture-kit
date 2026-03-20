import 'dart:io';

import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:screen_capture_kit_example/avi_isolate_recorder.dart';

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

    final index = _selectDisplayIndex(
      displays,
      parsed.displayOneBased,
    );
    if (index == null) {
      exitCode = 64;
      return;
    }

    final display = displays[index];

    // Cap fps to the display's refresh rate when it is known.
    var fps = parsed.fps;
    final refreshHz = display.refreshRate;
    if (refreshHz.isKnown && fps > refreshHz.value) {
      stdout.writeln(
        'Display refresh rate is ${refreshHz.value} Hz; '
        'capping --fps from $fps to ${refreshHz.value}.',
      );
      fps = refreshHz.value;
    }

    final hzLabel = refreshHz.isKnown ? '${refreshHz.value}Hz' : '?Hz';
    stdout.writeln(
      'Recording display ${index + 1}/${displays.length}: '
      'id=${display.displayId.value}  '
      '${display.width}x${display.height} @ $hzLabel',
    );

    final outWidth = parsed.width ?? display.width;
    final outHeight = parsed.height ?? display.height;
    if (outWidth <= 0 || outHeight <= 0) {
      stderr.writeln('Invalid frame size: ${outWidth}x$outHeight');
      exitCode = 64;
      return;
    }

    final outFile = _outputFile(
      parsed.outputDir,
      display,
      outWidth,
      outHeight,
    );
    filter = await kit.createDisplayFilter(display);

    await recordDisplayToAviIsolate(
      kit: kit,
      filter: filter!,
      outputFile: outFile,
      fps: fps,
      durationSeconds: parsed.durationSeconds,
      width: outWidth,
      height: outHeight,
    );

    stdout.writeln('Wrote: ${outFile.path}');
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
    required this.fps,
    this.displayOneBased,
    this.durationSeconds,
    this.width,
    this.height,
  });

  final Directory outputDir;
  final int? displayOneBased;
  final double? durationSeconds;
  final int fps;
  final int? width;
  final int? height;
}

_ParsedArgs? _parseArgs(List<String> args) {
  Directory? outDir;
  int? displayOneBased;
  double? durationSeconds;
  var fps = 30;
  int? width;
  int? height;

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
    if (a == '--duration' || a == '-t') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      durationSeconds = double.tryParse(args[++i]);
      if (durationSeconds == null || durationSeconds <= 0) {
        stderr.writeln('Invalid --duration value (use a positive number).');
        return null;
      }
      continue;
    }
    if (a == '--fps') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      fps = int.tryParse(args[++i]) ?? -1;
      if (fps < 1 || fps > 120) {
        stderr.writeln('Invalid --fps value (use 1..120).');
        return null;
      }
      continue;
    }
    if (a == '--width') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      width = int.tryParse(args[++i]);
      if (width == null || width < 1) {
        stderr.writeln('Invalid --width value (use a positive integer).');
        return null;
      }
      continue;
    }
    if (a == '--height') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      height = int.tryParse(args[++i]);
      if (height == null || height < 1) {
        stderr.writeln('Invalid --height value (use a positive integer).');
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
    durationSeconds: durationSeconds,
    fps: fps,
    width: width,
    height: height,
  );
}

void _printUsage() {
  stderr.writeln('''
Record a display to an uncompressed AVI (BGRA) using Dart only.

Usage:
  dart run bin/record_display.dart --out <dir> [options]
  dart run bin/record_display.dart <dir> [options]

Options:
  --out, -o <dir>       Output directory for the AVI (created if missing)
  --display, -d <n>    1-based display index (omit to choose interactively)
  --duration, -t <sec> Stop after this many seconds (omit: Ctrl+C)
  --fps <n>            Frame rate for the AVI header (default 30; 1..120)
  --width <px>         Output width in pixels (optional; default: display width)
  --height <px>        Output height in pixels (optional; default: display height)
''');
}

int? _selectDisplayIndex(List<Display> displays, int? displayOneBased) {
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

File _outputFile(
  Directory outputDir,
  Display display,
  int width,
  int height,
) {
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }
  final timestamp =
      DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final name = 'record_display_${display.displayId.value}_'
      '${width}x${height}_$timestamp.avi';
  return File('${outputDir.path}/$name');
}
