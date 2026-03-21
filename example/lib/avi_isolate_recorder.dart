import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:screen_capture_kit/screen_capture_kit.dart';

/// kCVPixelFormatType_32BGRA (FourCC BGRA). Matches ffmpeg `bgra`.
const cvPixelFormatType32Bgra = 0x42475241;

/// Writes an uncompressed AVI (BGRA) using a background isolate from [frames].
///
/// [onBeforeCancelFrameSubscription] runs in `finally` **before** the frame
/// subscription is canceled (which stops the native capture stream). Use this
/// to finalize parallel audio writers while the stream is still active.
///
/// When [deferDimensionsFromFirstFrame] is true, pass [width] and [height] as
/// `0`; the AVI header is written after the first [CapturedFrame] so picker or
/// variable-size capture does not need a known resolution up front.
Future<void> recordFramesToAviIsolate({
  required Stream<CapturedFrame> frames,
  required File outputFile,
  required int fps,
  required double? durationSeconds,
  required int width,
  required int height,
  bool deferDimensionsFromFirstFrame = false,
  Future<void> Function()? onBeforeCancelFrameSubscription,
  void Function(int captured, int dropped, int inFlight)? onCaptureStopped,
}) async {
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
      }
    }
  });

  await completerInit.future;

  writerCmdPort.send({
    'type': 'init',
    'outputPath': outputFile.path,
    'width': width,
    'height': height,
    'fps': fps,
    'deferHeaderUntilFirstFrame': deferDimensionsFromFirstFrame,
  });

  final sigSub = ProcessSignal.sigint.watch().listen((_) => requestStop());

  late final StreamSubscription<CapturedFrame> sub;
  sub = frames.listen(
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
      if (!deferDimensionsFromFirstFrame &&
          (frame.size.width != width || frame.size.height != height)) {
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
        'frameWidth': frame.size.width,
        'frameHeight': frame.size.height,
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

    final before = onBeforeCancelFrameSubscription;
    if (before != null) {
      await before();
    }

    await sub.cancel();
    onCaptureStopped?.call(capturedFrames, droppedFrames, inFlight);

    if (inFlight > 0) {
      await drainedCompleter.future;
    }

    writerCmdPort.send({'type': 'stop'});

    await doneCompleter.future;
    await mainSub.cancel();
    mainReceivePort.close();
  }
}

/// Prints delegate bridge events to stdout for manual verification when
/// `emitDelegateEvents: true` is used.
void logCaptureStreamDelegateEventToStdout(CaptureStreamDelegateEvent e) {
  switch (e.kind) {
    case CaptureStreamDelegateEventKind.didStopWithError:
      stdout.writeln(
        '[delegate] didStopWithError '
        'domain=${e.errorDomain} code=${e.errorCode} '
        'desc=${e.errorDescription}',
      );
    case CaptureStreamDelegateEventKind.outputVideoEffectDidStart:
      stdout.writeln('[delegate] outputVideoEffectDidStart');
    case CaptureStreamDelegateEventKind.outputVideoEffectDidStop:
      stdout.writeln('[delegate] outputVideoEffectDidStop');
  }
}

/// Same as [recordFramesToAviIsolate] after starting
/// `startCaptureStreamWithUpdater` with `emitDelegateEvents: true` so delegate
/// events appear on stdout.
///
/// [captureResolution] maps to `SCStreamConfiguration.captureResolution`
/// (macOS 14+); defaults to [CaptureResolution.automatic] (same default as the
/// screenshot example CLI).
///
/// The delegate subscription is canceled **after** [recordFramesToAviIsolate]
/// returns so `didStopWithError` is still delivered when the video subscription
/// stops the native stream.
Future<void> recordDisplayToAviIsolate({
  required ScreenCaptureKit kit,
  required FilterId filter,
  required File outputFile,
  required int fps,
  required double? durationSeconds,
  required int width,
  required int height,
  bool? scalesToFit,
  bool? preservesAspectRatio,
  CaptureResolution captureResolution = CaptureResolution.automatic,
}) async {
  stdout.writeln(
    'SCStreamDelegate bridge: lines prefixed with [delegate] '
    '(see emitDelegateEvents in startCaptureStreamWithUpdater).',
  );

  final capture = kit.startCaptureStreamWithUpdater(
    filter,
    frameSize: FrameSize(width: width, height: height),
    frameRate: FrameRate(fps),
    scalesToFit: scalesToFit,
    preservesAspectRatio: preservesAspectRatio,
    pixelFormat: cvPixelFormatType32Bgra,
    captureResolution: captureResolution,
    emitDelegateEvents: true,
  );

  StreamSubscription<CaptureStreamDelegateEvent>? delegateSub;
  delegateSub =
      capture.delegateEvents?.listen(logCaptureStreamDelegateEventToStdout);

  await recordFramesToAviIsolate(
    frames: capture.stream,
    outputFile: outputFile,
    fps: fps,
    durationSeconds: durationSeconds,
    width: width,
    height: height,
    onCaptureStopped: (captured, dropped, inFlight) {
      stdout.writeln(
        '録画完了: captured=$captured dropped=$dropped '
        '(writing continues, inFlight=$inFlight)...',
      );
    },
  );
  await delegateSub?.cancel();
}

void _aviWriterIsolateMain(SendPort mainSendPort) {
  final cmdPort = ReceivePort();
  mainSendPort.send(cmdPort.sendPort);

  RandomAccessFile? raf;
  int? width;
  int? height;
  int? fps;
  int? packedFrameBytes;

  final frameOffsets = <int>[];
  var frameCount = 0;

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

    const avifHasIndex = 0x10;

    raf!.writeFromSync(_fourccBytes('RIFF'));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_fourccBytes('AVI '));

    const avihChunkSize = 56;
    const strhChunkSize = 56;
    const strfChunkSize = 40;

    const strlListSizeField = 4 + (8 + strhChunkSize) + (8 + strfChunkSize);
    const strlListTotalBytes = 8 + strlListSizeField;
    const hdrlListSizeField = 4 + (8 + avihChunkSize) + strlListTotalBytes;

    raf!.writeFromSync(_fourccBytes('LIST'));
    raf!.writeFromSync(_u32leBytes(hdrlListSizeField));
    raf!.writeFromSync(_fourccBytes('hdrl'));

    final microSecPerFrame = (1000000 / fps!).round();
    raf!.writeFromSync(_fourccBytes('avih'));
    raf!.writeFromSync(_u32leBytes(avihChunkSize));
    raf!.writeFromSync(_u32leBytes(microSecPerFrame));
    raf!.writeFromSync(_u32leBytes(packedFrame * fps!));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(avifHasIndex));
    avihTotalFramesOffset = raf!.positionSync() + 16;
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(1));
    raf!.writeFromSync(_u32leBytes(packedFrame));
    raf!.writeFromSync(_u32leBytes(width!));
    raf!.writeFromSync(_u32leBytes(height!));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(0));

    raf!.writeFromSync(_fourccBytes('LIST'));
    raf!.writeFromSync(_u32leBytes(strlListSizeField));
    raf!.writeFromSync(_fourccBytes('strl'));

    raf!.writeFromSync(_fourccBytes('strh'));
    raf!.writeFromSync(_u32leBytes(strhChunkSize));
    raf!.writeFromSync(_fourccBytes('vids'));
    raf!.writeFromSync(_fourccBytes('DIB '));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u16leBytes(0));
    raf!.writeFromSync(_u16leBytes(0));
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(1));
    raf!.writeFromSync(_u32leBytes(fps!));
    raf!.writeFromSync(_u32leBytes(0));
    final strhStart = raf!.positionSync();
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_u32leBytes(packedFrame));
    raf!.writeFromSync(_u32leBytes(0xFFFFFFFF));
    raf!.writeFromSync(_u32leBytes(packedFrame));
    raf!.writeFromSync(_i16leBytes(0));
    raf!.writeFromSync(_i16leBytes(0));
    raf!.writeFromSync(_i16leBytes(width!));
    raf!.writeFromSync(_i16leBytes(height!));

    strhLengthOffset = strhStart;

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

    raf!.writeFromSync(_fourccBytes('LIST'));
    moviListSizeOffset = raf!.positionSync();
    raf!.writeFromSync(_u32leBytes(0));
    raf!.writeFromSync(_fourccBytes('movi'));
    moviDataStart = raf!.positionSync();
  }

  void patchAndFinalize() {
    if (raf == null ||
        width == null ||
        height == null ||
        fps == null ||
        packedFrameBytes == null) {
      return;
    }
    final packedFrame = packedFrameBytes!;

    final moviEndPos = raf!.positionSync();

    raf!.setPositionSync(avihTotalFramesOffset);
    raf!.writeFromSync(_u32leBytes(frameCount));
    raf!.setPositionSync(strhLengthOffset);
    raf!.writeFromSync(_u32leBytes(frameCount));

    final moviListSizeFieldValue = 4 + (moviEndPos - moviDataStart);
    raf!.setPositionSync(moviListSizeOffset);
    raf!.writeFromSync(_u32leBytes(moviListSizeFieldValue));

    raf!.setPositionSync(moviEndPos);
    raf!.writeFromSync(_fourccBytes('idx1'));
    raf!.writeFromSync(_u32leBytes(frameCount * 16));
    for (final off in frameOffsets) {
      raf!.writeFromSync(_fourccBytes('00db'));
      raf!.writeFromSync(_u32leBytes(0x10));
      raf!.writeFromSync(_u32leBytes(off));
      raf!.writeFromSync(_u32leBytes(packedFrame));
    }

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
      final deferHeader =
          message['deferHeaderUntilFirstFrame'] as bool? ?? false;
      final outputPath = message['outputPath'] as String;
      raf = await File(outputPath).open(mode: FileMode.write);
      if (!deferHeader && width! > 0 && height! > 0) {
        writeHeader();
      }
      return;
    }

    if (type == 'frame') {
      if (raf == null) {
        return;
      }
      final bytesPerRow = message['bytesPerRow'] as int;
      final ttd = message['bgra'] as TransferableTypedData;
      final bgra = ttd.materialize().asUint8List();
      final frameW = message['frameWidth'] as int?;
      final frameH = message['frameHeight'] as int?;
      if (packedFrameBytes == null &&
          frameW != null &&
          frameH != null &&
          frameW > 0 &&
          frameH > 0) {
        width = frameW;
        height = frameH;
        writeHeader();
      }
      if (packedFrameBytes == null) {
        return;
      }

      final dataStartAbsolute = raf!.positionSync() + 8;
      raf!.writeFromSync(_fourccBytes('00db'));
      raf!.writeFromSync(_u32leBytes(packedFrameBytes!));
      frameOffsets.add(dataStartAbsolute - moviDataStart);

      final w = width!;
      final h = height!;
      final packedRowBytes = w * 4;

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
