import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:screen_capture_kit/screen_capture_kit.dart';

// kCVPixelFormatType_32BGRA (FourCC BGRA, 0x42475241). Matches ffmpeg bgra.
const _kCvPixelFormatType32Bgra = 0x42475241;

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
    final hz = display.refreshRate;
    if (hz > 0 && fps > hz.toInt()) {
      stdout.writeln(
        'Display refresh rate is ${hz.toStringAsFixed(0)} Hz; '
        'capping --fps from $fps to ${hz.toInt()}.',
      );
      fps = hz.toInt();
    }

    final hzLabel = hz > 0 ? '${hz.toStringAsFixed(0)}Hz' : '?Hz';
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

    await _recordDisplayToUncompressedAviIsolateWriter(
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

// Writes an uncompressed AVI container with BGRA frames.
//
// This is intentionally simple (no streaming index rebuild). It writes:
// - RIFF/AVI headers with placeholders for frameCount
// - movi list with `00db` chunks containing packed BGRA rows
// - idx1 at the end
// Isolate-based writer path is enabled for the duration-compliance mode.
Future<void> _recordDisplayToUncompressedAviIsolateWriter({
  required ScreenCaptureKit kit,
  required FilterId filter,
  required File outputFile,
  required int fps,
  required double? durationSeconds,
  required int width,
  required int height,
}) async {
  // Writer isolate protocol:
  // - isolate sends a SendPort to accept commands
  // - main sends init/frame/stop
  // - isolate sends per-frame ack and a final done
  final mainReceivePort = ReceivePort();
  await Isolate.spawn(
    _aviWriterIsolateMain,
    mainReceivePort.sendPort,
    debugName: 'aviWriter',
  );

  late final SendPort writerCmdPort;
  final completerInit = Completer<void>();

  var inFlight = 0;
  var capturedFrames = 0;
  var droppedFrames = 0;
  var writtenFrames = 0;

  // Keep some frames buffered in flight. When exceeded, drop to avoid OOM.
  const maxInFlightFrames = 64;

  final stopSignal = Completer<void>();
  Timer? durationTimer;
  Timer? hardStopTimer;
  DateTime? durationStartAt;

  void requestStop() {
    if (!stopSignal.isCompleted) {
      stopSignal.complete();
    }
  }

  // Start duration timer on the first received frame so elapsed time matches
  // the actual recording window (not "time since command start").
  // Also keep a hard stop from process start to avoid hanging.
  const hardStopExtraSeconds = 10.0;
  if (durationSeconds != null) {
    hardStopTimer = Timer(
      Duration(
        microseconds:
            ((durationSeconds + hardStopExtraSeconds) * 1000000).round(),
      ),
      requestStop,
    );
  }

  final doneCompleter = Completer<void>();
  final drainedCompleter = Completer<void>();

  StreamSubscription<dynamic>? mainSub;
  mainSub = mainReceivePort.listen((dynamic message) {
    if (message is SendPort) {
      writerCmdPort = message;
      completerInit.complete();
      return;
    }
    if (message is Map) {
      final type = message['type'];
      if (type == 'frameWritten') {
        inFlight = (inFlight - 1).clamp(0, maxInFlightFrames);
        writtenFrames = (message['writtenFrames'] as int?) ?? writtenFrames;
        if (stopSignal.isCompleted &&
            inFlight == 0 &&
            !drainedCompleter.isCompleted) {
          drainedCompleter.complete();
        }
      } else if (type == 'done') {
        if (!doneCompleter.isCompleted) {
          doneCompleter.complete();
        }
        // Let the writer isolate exit naturally after finalization.
      }
    }
  });

  // Kick off the isolate init after handshake.
  await completerInit.future;

  writerCmdPort.send({
    'type': 'init',
    'outputPath': outputFile.path,
    'width': width,
    'height': height,
    'fps': fps,
  });

  // Ctrl+C should stop capture too.
  final sigSub = ProcessSignal.sigint.watch().listen((_) => requestStop());

  final stream = kit.startCaptureStream(
    filter,
    frameSize: FrameSize(width: width, height: height),
    frameRate: FrameRate(fps),
    pixelFormat: _kCvPixelFormatType32Bgra,
  );

  late final StreamSubscription<CapturedFrame> sub;
  sub = stream.listen(
    (frame) {
      if (stopSignal.isCompleted) {
        return;
      }
      durationStartAt ??= DateTime.now();
      if (durationSeconds != null && durationTimer == null) {
        durationTimer = Timer(
          Duration(microseconds: (durationSeconds * 1000000).round()),
          requestStop,
        );
      }
      if (frame.size.width != width || frame.size.height != height) {
        // Unexpected size changes; skip to keep AVI consistent.
        return;
      }

      capturedFrames++;
      if (inFlight >= maxInFlightFrames) {
        droppedFrames++;
        return;
      }
      inFlight++;

      final bytes = frame.bgraData;
      final ttd = TransferableTypedData.fromList([bytes]);
      writerCmdPort.send({
        'type': 'frame',
        'bgra': ttd,
        'bytesPerRow': frame.bytesPerRow,
      });
    },
    onError: (Object e, StackTrace st) {
      if (!stopSignal.isCompleted) {
        stopSignal.completeError(e, st);
      }
    },
    onDone: requestStop,
    cancelOnError: true,
  );

  try {
    await stopSignal.future;
  } finally {
    await sigSub.cancel();
    durationTimer?.cancel();
    hardStopTimer?.cancel();

    // Stop accepting frames, but wait for queued frames to be written.
    await sub.cancel();
    stdout.writeln(
      '録画完了: captured=$capturedFrames dropped=$droppedFrames '
      '(writing continues, inFlight=$inFlight)...',
    );

    if (inFlight > 0) {
      await drainedCompleter.future;
    }

    // Tell writer to finalize the AVI and patch headers.
    writerCmdPort.send({'type': 'stop'});

    await doneCompleter.future;
    await mainSub.cancel();
    mainReceivePort.close();
  }
}

void _aviWriterIsolateMain(SendPort mainSendPort) {
  final cmdPort = ReceivePort();
  mainSendPort.send(cmdPort.sendPort);

  // Writer state.
  RandomAccessFile? raf;
  int? width;
  int? height;
  int? fps;
  int? packedFrameBytes;

  final frameOffsets = <int>[];
  var frameCount = 0;

  // Patch points.
  const riffSizeOffset = 4;
  var moviListSizeOffset = 0;
  var avihTotalFramesOffset = 0;
  var strhLengthOffset = 0;
  var moviDataStart = 0;

  void writeHeader() {
    if (raf == null || width == null || height == null || fps == null) {
      return;
    }

    final packedRow = width! * 4;
    final packedFrame = packedRow * height!;
    packedFrameBytes = packedFrame;

    // AVI uses top-down when biHeight is negative.
    const avifHasIndex = 0x10;

    // --- RIFF header ---
    raf!.writeFromSync(_fourccBytes('RIFF'));
    raf!.writeFromSync(_u32leBytes(0)); // RIFF size placeholder
    raf!.writeFromSync(_fourccBytes('AVI '));

    // --- hdrl list ---
    const avihChunkSize = 56;
    const strhChunkSize = 56;
    const strfChunkSize = 40;

    // LIST sizes.
    const strlListSizeField = 4 + (8 + strhChunkSize) + (8 + strfChunkSize);
    const strlListTotalBytes = 8 + strlListSizeField;
    const hdrlListSizeField = 4 + (8 + avihChunkSize) + strlListTotalBytes;

    raf!.writeFromSync(_fourccBytes('LIST'));
    raf!.writeFromSync(_u32leBytes(hdrlListSizeField));
    raf!.writeFromSync(_fourccBytes('hdrl'));

    // avih
    final microSecPerFrame = (1000000 / fps!).round();
    raf!.writeFromSync(_fourccBytes('avih'));
    raf!.writeFromSync(_u32leBytes(avihChunkSize));
    raf!.writeFromSync(_u32leBytes(microSecPerFrame));
    raf!.writeFromSync(_u32leBytes(packedFrame * fps!));
    raf!.writeFromSync(_u32leBytes(0)); // dwPaddingGranularity
    raf!.writeFromSync(_u32leBytes(avifHasIndex));
    avihTotalFramesOffset = raf!.positionSync() + 16;
    raf!.writeFromSync(_u32leBytes(0)); // dwTotalFrames
    raf!.writeFromSync(_u32leBytes(0)); // dwInitialFrames
    raf!.writeFromSync(_u32leBytes(1)); // dwStreams
    raf!.writeFromSync(_u32leBytes(packedFrame)); // dwSuggestedBufferSize
    raf!.writeFromSync(_u32leBytes(width!));
    raf!.writeFromSync(_u32leBytes(height!));
    raf!.writeFromSync(_u32leBytes(0)); // reserved
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(0));

    // strl
    raf!.writeFromSync(_fourccBytes('LIST'));
    raf!.writeFromSync(
      _u32leBytes(strlListSizeField),
    );
    raf!.writeFromSync(_fourccBytes('strl'));

    // strh
    raf!.writeFromSync(_fourccBytes('strh'));
    raf!.writeFromSync(_u32leBytes(strhChunkSize));
    raf!.writeFromSync(_fourccBytes('vids'));
    raf!.writeFromSync(_fourccBytes('DIB '));
    raf!.writeFromSync(_u32leBytes(0)); // dwFlags
    raf!.writeFromSync(_u16leBytes(0)); // wPriority
    raf!.writeFromSync(_u16leBytes(0)); // wLanguage
    raf!.writeFromSync(_u32leBytes(0)); // dwInitialFrames
    raf!.writeFromSync(_u32leBytes(1)); // dwScale
    raf!.writeFromSync(_u32leBytes(fps!)); // dwRate
    raf!.writeFromSync(_u32leBytes(0)); // dwStart
    final strhStart = raf!.positionSync();
    raf!.writeFromSync(_u32leBytes(0)); // dwLength
    raf!.writeFromSync(_u32leBytes(packedFrame)); // dwSuggestedBufferSize
    raf!.writeFromSync(_u32leBytes(0xFFFFFFFF)); // dwQuality
    raf!.writeFromSync(_u32leBytes(packedFrame)); // dwSampleSize
    raf!.writeFromSync(_i16leBytes(0));
    raf!.writeFromSync(_i16leBytes(0));
    raf!.writeFromSync(_i16leBytes(width!));
    raf!.writeFromSync(_i16leBytes(height!));

    strhLengthOffset = strhStart;

    // strf
    raf!.writeFromSync(_fourccBytes('strf'));
    raf!.writeFromSync(_u32leBytes(strfChunkSize));
    raf!.writeFromSync(_u32leBytes(40));
    raf!.writeFromSync(_i32leBytes(width!));
    raf!.writeFromSync(_i32leBytes(-height!));
    raf!.writeFromSync(_u16leBytes(1));
    raf!.writeFromSync(_u16leBytes(32));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(packedFrame));
    raf!.writeFromSync(_i32leBytes(0));
    raf!.writeFromSync(_i32leBytes(0));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(0));

    // movi list placeholder
    raf!.writeFromSync(_fourccBytes('LIST'));
    moviListSizeOffset = raf!.positionSync();
    raf!.writeFromSync(_u32leBytes(0)); // movi list size
    raf!.writeFromSync(_fourccBytes('movi'));
    moviDataStart = raf!.positionSync();
  }

  void patchAndFinalize() {
    if (raf == null || width == null || height == null || fps == null) {
      return;
    }
    final packedFrame = packedFrameBytes!;

    final moviEndPos = raf!.positionSync();

    // Patch dwTotalFrames and dwLength.
    raf!.setPositionSync(avihTotalFramesOffset);
    raf!.writeFromSync(_u32leBytes(frameCount));
    raf!.setPositionSync(strhLengthOffset);
    raf!.writeFromSync(_u32leBytes(frameCount));

    // dwRate stays at the requested fps (set in writeHeader).

    // Patch movi size.
    final moviListSizeFieldValue = 4 + (moviEndPos - moviDataStart);
    raf!.setPositionSync(moviListSizeOffset);
    raf!.writeFromSync(_u32leBytes(moviListSizeFieldValue));

    // Restore pointer and write idx1.
    raf!.setPositionSync(moviEndPos);
    raf!.writeFromSync(_fourccBytes('idx1'));
    raf!.writeFromSync(_u32leBytes(frameCount * 16));
    for (final off in frameOffsets) {
      raf!.writeFromSync(_fourccBytes('00db'));
      raf!.writeFromSync(_u32leBytes(0x10));
      raf!.writeFromSync(_u32leBytes(off));
      raf!.writeFromSync(_u32leBytes(packedFrame));
    }

    // Patch RIFF size.
    final fileEnd = raf!.positionSync();
    final riffSize = fileEnd - 8;
    raf!.setPositionSync(riffSizeOffset);
    raf!.writeFromSync(_u32leBytes(riffSize));

    raf!.closeSync();
  }

  cmdPort.listen((dynamic message) async {
    if (message is! Map) {
      return;
    }
    final type = message['type'];

    if (type == 'init') {
      width = message['width'] as int;
      height = message['height'] as int;
      fps = message['fps'] as int;
      final outputPath = message['outputPath'] as String;
      raf = await File(outputPath).open(mode: FileMode.write);
      writeHeader();
      return;
    }

    if (type == 'frame') {
      if (raf == null) {
        return;
      }
      final bytesPerRow = message['bytesPerRow'] as int;
      final ttd = message['bgra'] as TransferableTypedData;
      final bgra = ttd.materialize().asUint8List();

      final dataStartAbsolute = raf!.positionSync() + 8;
      raf!.writeFromSync(_fourccBytes('00db'));
      raf!.writeFromSync(_u32leBytes(packedFrameBytes!));
      frameOffsets.add(dataStartAbsolute - moviDataStart);

      final w = width!;
      final h = height!;
      final packedRowBytes = w * 4;

      // Build the packed frame in a single buffer to minimize syscalls.
      final packed = Uint8List(packedFrameBytes!);
      for (var y = 0; y < h; y++) {
        final srcOffset = y * bytesPerRow;
        final dstOffset = y * packedRowBytes;
        if (srcOffset < bgra.length) {
          final available = bgra.length - srcOffset;
          final copyLen =
              available >= packedRowBytes ? packedRowBytes : available;
          if (copyLen > 0) {
            packed.setRange(dstOffset, dstOffset + copyLen, bgra, srcOffset);
          }
        }
      }
      raf!.writeFromSync(packed);

      // Ensure we wrote exactly packedFrameBytes.
      frameCount++;
      mainSendPort.send({
        'type': 'frameWritten',
        'writtenFrames': frameCount,
      });
      return;
    }

    if (type == 'stop') {
      patchAndFinalize();
      mainSendPort.send({'type': 'done'});
      cmdPort.close();
      return;
    }
  });
}

// Kept as a reference implementation; the CLI uses the isolate writer.
// ignore: unused_element
Future<void> _recordDisplayToUncompressedAvi({
  required ScreenCaptureKit kit,
  required FilterId filter,
  required File outputFile,
  required int fps,
  required double? durationSeconds,
  required int width,
  required int height,
}) async {
  final packedRowBytes = width * 4;
  final packedFrameBytes = packedRowBytes * height;
  final microSecPerFrame = (1000000 / fps).round();

  // AVI uses top-down when biHeight is negative.
  const avifHasIndex = 0x10;
  final raf = outputFile.openSync(mode: FileMode.write);
  final frameOffsets = <int>[];

  // Placeholders/patch points.
  const riffSizeOffset = 4;
  var moviListSizeOffset = 0; // patched later
  var avihTotalFramesOffset = 0;
  var strhLengthOffset = 0;
  var moviDataStart = 0;

  DateTime? durationStartAt;

  // --- RIFF header ---
  raf.writeFromSync(_fourccBytes('RIFF'));
  raf.writeFromSync(_u32leBytes(0)); // RIFF size placeholder
  raf.writeFromSync(_fourccBytes('AVI '));

  // --- hdrl list ---
  const avihChunkSize = 56;
  const avihChunkTotalBytes = 8 + avihChunkSize;

  const strhChunkSize = 56;
  const strhChunkTotalBytes = 8 + strhChunkSize;

  const strfChunkSize = 40;
  const strfChunkTotalBytes = 8 + strfChunkSize;

  // LIST 'strl' size field includes the 'strl' tag itself.
  const strlListSizeField = 4 + strhChunkTotalBytes + strfChunkTotalBytes;
  const strlListTotalBytes = 8 + strlListSizeField;

  // LIST 'hdrl' size field includes the 'hdrl' tag itself.
  const hdrlListSizeField =
      4 + avihChunkTotalBytes + strlListTotalBytes; // 'hdrl' + payload
  raf.writeFromSync(_fourccBytes('LIST'));
  raf.writeFromSync(_u32leBytes(hdrlListSizeField));
  raf.writeFromSync(_fourccBytes('hdrl'));

  // avih
  raf.writeFromSync(_fourccBytes('avih'));
  raf.writeFromSync(_u32leBytes(avihChunkSize));
  final avihStart = raf.positionSync();
  raf.writeFromSync(_u32leBytes(microSecPerFrame));
  raf.writeFromSync(
    _u32leBytes(packedFrameBytes * fps),
  ); // dwMaxBytesPerSec (approx)
  raf.writeFromSync(_u32leBytes(0)); // dwPaddingGranularity
  raf.writeFromSync(_u32leBytes(avifHasIndex));
  // dwTotalFrames placeholder
  avihTotalFramesOffset = avihStart + 16;
  // after dwMicroSecPerFrame(0) + dwMaxBytesPerSec(4)
  // + dwPadding(8) + dwFlags(12)
  raf.writeFromSync(_u32leBytes(0));
  raf.writeFromSync(_u32leBytes(0)); // dwInitialFrames
  raf.writeFromSync(_u32leBytes(1)); // dwStreams
  raf.writeFromSync(_u32leBytes(packedFrameBytes)); // dwSuggestedBufferSize
  raf.writeFromSync(_u32leBytes(width)); // dwWidth
  raf.writeFromSync(_u32leBytes(height)); // dwHeight
  // dwReserved[4]
  raf.writeFromSync(_u32leBytes(0));
  raf.writeFromSync(_u32leBytes(0));
  raf.writeFromSync(_u32leBytes(0));
  raf.writeFromSync(_u32leBytes(0));

  // strl
  raf.writeFromSync(_fourccBytes('LIST'));
  raf.writeFromSync(_u32leBytes(strlListSizeField));
  raf.writeFromSync(_fourccBytes('strl'));

  // strh
  raf.writeFromSync(_fourccBytes('strh'));
  raf.writeFromSync(_u32leBytes(strhChunkSize));
  raf.writeFromSync(_fourccBytes('vids')); // fccType
  raf.writeFromSync(_fourccBytes('DIB ')); // fccHandler: uncompressed
  raf.writeFromSync(_u32leBytes(0)); // dwFlags
  raf.writeFromSync(_u16leBytes(0)); // wPriority
  raf.writeFromSync(_u16leBytes(0)); // wLanguage
  raf.writeFromSync(_u32leBytes(0)); // dwInitialFrames
  raf.writeFromSync(_u32leBytes(1)); // dwScale
  raf.writeFromSync(_u32leBytes(fps)); // dwRate
  raf.writeFromSync(_u32leBytes(0)); // dwStart
  // dwLength placeholder
  final strhStart = raf.positionSync();
  // BITMAPINFOHEADER layout:
  // fccType(4) + fccHandler(4) + dwFlags(4) + wPriority(2) + wLanguage(2)
  // + dwInitialFrames(4) + dwScale(4) + dwRate(4) + dwStart(4) = 32 bytes
  // => dwLength is at offset 32 from strhStart.
  strhLengthOffset = strhStart + 32;
  raf.writeFromSync(_u32leBytes(0)); // dwLength
  raf.writeFromSync(_u32leBytes(packedFrameBytes)); // dwSuggestedBufferSize
  raf.writeFromSync(_u32leBytes(0xFFFFFFFF)); // dwQuality
  raf.writeFromSync(_u32leBytes(packedFrameBytes)); // dwSampleSize
  // rcFrame: left, top, right, bottom
  raf.writeFromSync(_i16leBytes(0));
  raf.writeFromSync(_i16leBytes(0));
  raf.writeFromSync(_i16leBytes(width));
  raf.writeFromSync(_i16leBytes(height));

  // strf (BITMAPINFOHEADER)
  raf.writeFromSync(_fourccBytes('strf'));
  raf.writeFromSync(_u32leBytes(strfChunkSize));
  raf.writeFromSync(_u32leBytes(40)); // biSize
  raf.writeFromSync(_i32leBytes(width)); // biWidth
  raf.writeFromSync(_i32leBytes(-height)); // biHeight: top-down
  raf.writeFromSync(_u16leBytes(1)); // biPlanes
  raf.writeFromSync(_u16leBytes(32)); // biBitCount
  raf.writeFromSync(_u32leBytes(0)); // biCompression: BI_RGB
  raf.writeFromSync(_u32leBytes(packedFrameBytes)); // biSizeImage
  raf.writeFromSync(_i32leBytes(0)); // biXPelsPerMeter
  raf.writeFromSync(_i32leBytes(0)); // biYPelsPerMeter
  raf.writeFromSync(_u32leBytes(0)); // biClrUsed
  raf.writeFromSync(_u32leBytes(0)); // biClrImportant

  // --- movi list (data) ---
  raf.writeFromSync(_fourccBytes('LIST'));
  // Absolute position of the movi list size field.
  moviListSizeOffset = raf.positionSync();
  raf.writeFromSync(_u32leBytes(0)); // movi list size placeholder
  raf.writeFromSync(_fourccBytes('movi'));
  moviDataStart = raf.positionSync(); // start of first chunk data

  // --- Capture and write frames ---
  final stream = kit.startCaptureStream(
    filter,
    frameSize: FrameSize(width: width, height: height),
    frameRate: FrameRate(fps),
    pixelFormat: _kCvPixelFormatType32Bgra,
  );

  final stopSignal = Completer<void>();
  StreamSubscription<CapturedFrame>? sub;

  Timer? durationTimer;
  Timer? hardStopTimer;

  void requestStop() {
    if (!stopSignal.isCompleted) {
      stopSignal.complete();
    }
  }

  // Ctrl+C should stop capture too.
  final sigSub = ProcessSignal.sigint.watch().listen((_) => requestStop());

  // Sequential write queue to preserve chunk ordering.
  var writeChain = Future<void>.value();
  var frameCount = 0;

  void startTimersOnce() {
    if (durationSeconds == null || durationTimer != null) {
      return;
    }
    const hardStopExtraSeconds = 10.0;
    durationTimer = Timer(
      Duration(microseconds: (durationSeconds * 1000000).round()),
      requestStop,
    );
    hardStopTimer = Timer(
      Duration(
        microseconds:
            ((durationSeconds + hardStopExtraSeconds) * 1000000).round(),
      ),
      requestStop,
    );
    durationStartAt ??= DateTime.now();
  }

  sub = stream.listen(
    (frame) {
      writeChain = writeChain.then((_) {
        if (stopSignal.isCompleted) {
          return;
        }
        if (frame.size.width != width || frame.size.height != height) {
          // Unexpected size changes; skip to keep AVI consistent.
          return;
        }

        startTimersOnce();

        final dataStartAbsolute = raf.positionSync() + 8; // after chunk header
        // chunk header: 4 bytes id + 4 bytes size
        raf.writeFromSync(_fourccBytes('00db'));
        raf.writeFromSync(_u32leBytes(packedFrameBytes));
        final moviOffset = dataStartAbsolute - moviDataStart;
        frameOffsets.add(moviOffset);

        _writePackedBgraFrame(raf, frame, width: width, height: height);
        frameCount++;
      });
    },
    onError: (Object e, StackTrace st) {
      if (!stopSignal.isCompleted) {
        stopSignal.completeError(e, st);
      }
    },
    onDone: requestStop,
    cancelOnError: true,
  );

  try {
    await stopSignal.future;
  } on Object {
    rethrow;
  } finally {
    await sigSub.cancel();
    durationTimer?.cancel();
    hardStopTimer?.cancel();
    await sub.cancel();
    await writeChain;
  }

  // At this point, the file pointer is at the end of movi data.
  final moviEndPos = raf.positionSync();

  // --- Patch frameCount in headers ---
  raf.setPositionSync(avihTotalFramesOffset);
  raf.writeFromSync(_u32leBytes(frameCount));
  raf.setPositionSync(strhLengthOffset);
  raf.writeFromSync(_u32leBytes(frameCount));

  // dwRate stays at the requested fps (set in the header above).

  // Patch movi size (size field includes 'movi' tag (4 bytes) + data bytes).
  final moviListSizeFieldValue = 4 + (moviEndPos - moviDataStart);
  raf.setPositionSync(moviListSizeOffset);
  raf.writeFromSync(_u32leBytes(moviListSizeFieldValue));

  // Restore file pointer to movi end before writing idx1.
  raf.setPositionSync(moviEndPos);

  // --- Write idx1 ---
  raf.writeFromSync(_fourccBytes('idx1'));
  raf.writeFromSync(_u32leBytes(frameCount * 16));
  for (final off in frameOffsets) {
    raf.writeFromSync(_fourccBytes('00db'));
    raf.writeFromSync(_u32leBytes(0x10)); // flags: keyframe
    raf.writeFromSync(_u32leBytes(off));
    raf.writeFromSync(_u32leBytes(packedFrameBytes));
  }

  // Patch RIFF size.
  final fileEnd = raf.positionSync();
  final riffSize =
      fileEnd - 8; // RIFF size excludes 'RIFF' and size field itself
  raf.setPositionSync(riffSizeOffset);
  raf.writeFromSync(_u32leBytes(riffSize));

  await raf.close();
}

void _writePackedBgraFrame(
  RandomAccessFile raf,
  CapturedFrame frame, {
  required int width,
  required int height,
}) {
  final packedRowBytes = width * 4;
  final bpr = frame.bytesPerRow;
  final data = frame.bgraData;

  final row = Uint8List(packedRowBytes);
  for (var y = 0; y < height; y++) {
    row.fillRange(0, packedRowBytes, 0);
    final srcRowStart = y * bpr;
    if (srcRowStart < data.length) {
      final available = data.length - srcRowStart;
      final copyLen = available >= packedRowBytes ? packedRowBytes : available;
      if (copyLen > 0) {
        row.setRange(0, copyLen, data, srcRowStart);
      }
    }
    raf.writeFromSync(row);
  }
}

Uint8List _fourccBytes(String s) {
  final units = s.codeUnits;
  if (units.length != 4) {
    throw ArgumentError('FourCC must be 4 chars: $s');
  }
  return Uint8List.fromList(units);
}

Uint8List _u32leBytes(int v) {
  final bd = ByteData(4);
  bd.setUint32(0, v, Endian.little);
  return bd.buffer.asUint8List();
}

Uint8List _u16leBytes(int v) {
  final bd = ByteData(2);
  bd.setUint16(0, v, Endian.little);
  return bd.buffer.asUint8List();
}

Uint8List _i32leBytes(int v) {
  final bd = ByteData(4);
  bd.setInt32(0, v, Endian.little);
  return bd.buffer.asUint8List();
}

Uint8List _i16leBytes(int v) {
  final bd = ByteData(2);
  bd.setInt16(0, v, Endian.little);
  return bd.buffer.asUint8List();
}
