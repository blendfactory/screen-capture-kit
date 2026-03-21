import 'dart:async';
import 'dart:io';

import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:screen_capture_kit_example/avi_isolate_recorder.dart';
import 'package:screen_capture_kit_example/cli_capture_resolution.dart';
import 'package:screen_capture_kit_example/pcm_wav_writer.dart';

/// Records content chosen via [ScreenCaptureKit.presentContentSharingPicker] to
/// H.264/AAC MP4 (ffmpeg). Target FPS defaults to 120 and is capped by the
/// highest known display refresh rate from [ShareableContent.displays].
Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed == null) {
    _printUsage();
    exitCode = 64;
    return;
  }

  if (!Platform.isMacOS) {
    stderr.writeln('This tool only runs on macOS.');
    exitCode = 2;
    return;
  }

  final ffmpeg = await _resolveFfmpeg();
  if (ffmpeg == null) {
    stderr.writeln(
      'ffmpeg not found. Install it (e.g. brew install ffmpeg) and ensure '
      'it is on PATH.',
    );
    exitCode = 69;
    return;
  }

  final kit = ScreenCaptureKit();
  FilterId? filter;

  try {
    final content = await kit.getShareableContent();
    final fps = _capFpsToDisplays(parsed.requestedFps, content.displays);

    stdout.writeln(
      'Opening system content-sharing picker (macOS 14+). '
      'Choose a display, window, or app.',
    );
    stdout.writeln(
      'Target FPS: $fps (capped from ${parsed.requestedFps} using display '
      'refresh rates).',
    );
    stdout.writeln(
      'Tip: the capture UI may appear in Control Center (menu bar), not only '
      'as a window in front of Terminal.',
    );

    filter = await kit.presentContentSharingPicker(
      allowedModes: [
        ContentSharingPickerMode.singleDisplay,
        ContentSharingPickerMode.singleWindow,
        ContentSharingPickerMode.singleApplication,
      ],
    );

    if (filter == null) {
      stdout.writeln('Picker cancelled.');
      exitCode = 0;
      return;
    }

    final capturesSystem = parsed.audioMode == _AudioMode.system ||
        parsed.audioMode == _AudioMode.both;
    final capturesMic = parsed.audioMode == _AudioMode.mic ||
        parsed.audioMode == _AudioMode.both;

    if (capturesMic) {
      stdout.writeln(
        'Microphone capture requires macOS 15+. Grant access if prompted.',
      );
    }

    if (!parsed.outputDir.existsSync()) {
      parsed.outputDir.createSync(recursive: true);
    }

    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final base = 'record_picker_av_$ts';
    final dir = parsed.outputDir.path;
    final aviFile = File('$dir/${base}_video.avi');
    final sysWavFile = File('$dir/${base}_system.wav');
    final micWavFile = File('$dir/${base}_mic.wav');
    final mp4File = File('$dir/$base.mp4');

    if ((parsed.width != null) != (parsed.height != null)) {
      stderr.writeln('Use both --width and --height, or omit both.');
      exitCode = 64;
      return;
    }

    final refDisplay = _referenceDisplayForPicker(content.displays);
    final outWidth = parsed.width ?? refDisplay.width;
    final outHeight = parsed.height ?? refDisplay.height;
    if (outWidth <= 0 || outHeight <= 0) {
      stderr.writeln('Invalid frame size: ${outWidth}x$outHeight');
      exitCode = 64;
      return;
    }

    final frameSize = FrameSize(width: outWidth, height: outHeight);
    if (parsed.width == null && parsed.height == null) {
      stdout.writeln(
        'Frame size: ${outWidth}x$outHeight '
        '(default: reference display id=${refDisplay.displayId.value}).',
      );
    }

    final capture = kit.startCaptureStreamWithUpdater(
      filter!,
      frameSize: frameSize,
      frameRate: FrameRate(fps),
      pixelFormat: cvPixelFormatType32Bgra,
      scalesToFit: parsed.scalesToFit,
      preservesAspectRatio: parsed.preservesAspectRatio,
      captureResolution: parsed.captureResolution,
      capturesAudio: capturesSystem,
      excludesCurrentProcessAudio: true,
      captureMicrophone: capturesMic,
    );

    PcmWavWriter? sysWriter;
    PcmWavWriter? micWriter;
    StreamSubscription<CapturedAudio>? sysSub;
    StreamSubscription<CapturedAudio>? micSub;

    Object? audioErr;
    StackTrace? audioSt;
    void logAudioErr(Object e, StackTrace st) {
      audioErr ??= e;
      audioSt ??= st;
    }

    if (capturesSystem) {
      final s = capture.audioStream;
      if (s == null) {
        stderr.writeln('System audio is unavailable for this stream.');
        exitCode = 1;
        return;
      }
      sysWriter = PcmWavWriter(sysWavFile);
      sysSub = s.listen(
        sysWriter.add,
        onError: logAudioErr,
      );
    }

    if (capturesMic) {
      final m = capture.microphoneStream;
      if (m == null) {
        stderr.writeln(
          'Microphone stream unavailable (macOS 15+ required). '
          'Re-run with --audio system or --audio none.',
        );
        exitCode = 1;
        return;
      }
      micWriter = PcmWavWriter(micWavFile);
      micSub = m.listen(
        micWriter.add,
        onError: logAudioErr,
      );
    }

    Future<void> sealAudio() async {
      await sysSub?.cancel();
      await micSub?.cancel();
      sysSub = null;
      micSub = null;

      await capture.flushPendingAudio(
        onSystemAudio: sysWriter?.add,
        onMicrophoneAudio: micWriter?.add,
      );

      final sw = sysWriter;
      final mw = micWriter;
      if (sw != null && mw != null && sw.hasAudio && mw.hasAudio) {
        final sysCh = sw.channelCount;
        final micCh = mw.channelCount;
        final sysB = sw.pcmBytesWritten;
        final micB = mw.pcmBytesWritten;
        var micPadTarget = 0;
        if (sysCh == 2 && micCh == 1) {
          micPadTarget = sysB ~/ 2;
        } else if (sysCh != null && micCh != null && sysCh == micCh) {
          micPadTarget = sysB;
        }
        if (micPadTarget > 0 && micB < micPadTarget) {
          mw.padSilenceToPcmBytesSync(micPadTarget);
        }
      }

      sw?.finalizeSync();
      mw?.finalizeSync();
    }

    await recordFramesToAviIsolate(
      frames: capture.stream,
      outputFile: aviFile,
      fps: fps,
      durationSeconds: parsed.durationSeconds,
      width: outWidth,
      height: outHeight,
      onBeforeCancelFrameSubscription: sealAudio,
      onCaptureStopped: (captured, dropped, inFlight) {
        stdout.writeln(
          '録画完了: captured=$captured dropped=$dropped '
          '(writing continues, inFlight=$inFlight)...',
        );
      },
    );

    if (audioErr != null) {
      stderr.writeln('Audio capture error: $audioErr\n$audioSt');
      exitCode = 1;
      return;
    }

    stdout.writeln('Muxing with ffmpeg → ${mp4File.path}');
    final muxCode = await _runFfmpeg(
      ffmpegPath: ffmpeg,
      avi: aviFile,
      systemWav: sysWavFile,
      micWav: micWavFile,
      mp4Out: mp4File,
      hasSystemAudio: sysWriter?.hasAudio ?? false,
      hasMicAudio: micWriter?.hasAudio ?? false,
    );

    if (muxCode != 0) {
      stderr.writeln('ffmpeg exited with code $muxCode.');
      exitCode = 1;
      return;
    }

    if (!parsed.keepTemp) {
      try {
        if (aviFile.existsSync()) {
          await aviFile.delete();
        }
        if (sysWavFile.existsSync()) {
          await sysWavFile.delete();
        }
        if (micWavFile.existsSync()) {
          await micWavFile.delete();
        }
      } on Object catch (e) {
        stderr.writeln('Warning: could not delete temp files: $e');
      }
    }

    stdout.writeln('Wrote: ${mp4File.path}');
    if (parsed.keepTemp) {
      stdout.writeln(
        'Kept intermediates: ${aviFile.path}, '
        '${sysWavFile.path}, ${micWavFile.path}',
      );
    }
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

enum _AudioMode { none, system, mic, both }

class _ParsedArgs {
  const _ParsedArgs({
    required this.outputDir,
    required this.requestedFps,
    this.durationSeconds,
    this.width,
    this.height,
    this.keepTemp = false,
    this.scalesToFit,
    this.preservesAspectRatio,
    this.audioMode = _AudioMode.both,
    this.captureResolution = CaptureResolution.automatic,
  });

  final Directory outputDir;
  final int requestedFps;
  final double? durationSeconds;
  final int? width;
  final int? height;
  final bool keepTemp;
  final bool? scalesToFit;
  final bool? preservesAspectRatio;
  final _AudioMode audioMode;
  final CaptureResolution captureResolution;
}

/// Display used for default `--width`/`--height` when both are omitted: prefer
/// the highest known refresh rate, break ties by largest pixel area.
Display _referenceDisplayForPicker(List<Display> displays) {
  assert(displays.isNotEmpty, 'displays must not be empty');
  return displays.reduce((a, b) {
    final ar = a.refreshRate.isKnown ? a.refreshRate.value : -1;
    final br = b.refreshRate.isKnown ? b.refreshRate.value : -1;
    if (br != ar) {
      return br > ar ? b : a;
    }
    final aa = a.width * a.height;
    final ba = b.width * b.height;
    return ba > aa ? b : a;
  });
}

/// Caps [desired] to at most 120 and to the highest known display refresh rate.
int _capFpsToDisplays(int desired, List<Display> displays) {
  var fps = desired.clamp(1, 120);
  final knownHz = displays
      .where((d) => d.refreshRate.isKnown)
      .map((d) => d.refreshRate.value)
      .toList();
  if (knownHz.isEmpty) {
    return fps;
  }
  final maxRefresh = knownHz.reduce((a, b) => a > b ? a : b);
  if (fps > maxRefresh) {
    stdout.writeln(
      'Capping FPS from $fps to $maxRefresh Hz (max known display refresh).',
    );
    fps = maxRefresh;
  }
  return fps;
}

_ParsedArgs? _parseArgs(List<String> args) {
  Directory? outDir;
  double? durationSeconds;
  var requestedFps = 120;
  int? width;
  int? height;
  var keepTemp = false;
  bool? scalesToFit;
  bool? preservesAspectRatio;
  var audioMode = _AudioMode.both;
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
      requestedFps = int.tryParse(args[++i]) ?? -1;
      if (requestedFps < 1 || requestedFps > 120) {
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
    if (a == '--keep-temp') {
      keepTemp = true;
      continue;
    }
    if (a == '--scales-to-fit') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      final v = args[++i].toLowerCase();
      switch (v) {
        case 'true':
        case '1':
        case 'on':
        case 'yes':
          scalesToFit = true;
        case 'false':
        case '0':
        case 'off':
        case 'no':
          scalesToFit = false;
        default:
          stderr.writeln('Invalid --scales-to-fit (use true/false).');
          return null;
      }
      continue;
    }
    if (a == '--preserves-aspect-ratio') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      final v = args[++i].toLowerCase();
      switch (v) {
        case 'true':
        case '1':
        case 'on':
        case 'yes':
          preservesAspectRatio = true;
        case 'false':
        case '0':
        case 'off':
        case 'no':
          preservesAspectRatio = false;
        default:
          stderr.writeln(
            'Invalid --preserves-aspect-ratio (use true/false).',
          );
          return null;
      }
      continue;
    }
    if (a == '--audio') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      final v = args[++i].toLowerCase();
      switch (v) {
        case 'none':
          audioMode = _AudioMode.none;
        case 'system':
          audioMode = _AudioMode.system;
        case 'mic':
        case 'microphone':
          audioMode = _AudioMode.mic;
        case 'both':
          audioMode = _AudioMode.both;
        default:
          stderr.writeln(
            'Invalid --audio (use none, system, mic, both).',
          );
          return null;
      }
      continue;
    }
    if (a == '--quality' || a == '-q') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $a');
        return null;
      }
      final parsedQuality = tryParseCaptureResolutionCli(args[++i]);
      if (parsedQuality == null) {
        stderr.writeln(
          'Invalid --quality (use automatic, best, or nominal).',
        );
        return null;
      }
      quality = parsedQuality;
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
    requestedFps: requestedFps,
    durationSeconds: durationSeconds,
    width: width,
    height: height,
    keepTemp: keepTemp,
    scalesToFit: scalesToFit,
    preservesAspectRatio: preservesAspectRatio,
    audioMode: audioMode,
    captureResolution: quality,
  );
}

void _printUsage() {
  stderr.writeln('''
Record picker-selected content (display / window / app) to H.264/AAC MP4 via ffmpeg.

Uses presentContentSharingPicker (macOS 14+). Default FPS is 120, capped down to
the highest known connected display refresh rate.

Requirements:
  ffmpeg on PATH (e.g. brew install ffmpeg)
  macOS 13+ for system audio; macOS 15+ for microphone
  Screen Recording (+ Microphone if --audio mic/both)

Usage:
  dart run bin/record_picker_with_audio.dart --out <dir> [options]
  dart run bin/record_picker_with_audio.dart <dir> [options]

Options:
  --out, -o <dir>     Output directory (created if missing)
  --duration, -t <s>  Stop after seconds (omit → Ctrl+C)
  --fps <n>           Requested FPS (default 120; 1..120, then capped to display)
  --width, --height   Fixed output size (pass both; omit → reference display size)
  --audio <mode>      none | system | mic | both (default: both)
  --scales-to-fit <b> Map to SCStreamConfiguration.scalesToFit (true/false; omit to keep native default)
  --preserves-aspect-ratio <b> Map to SCStreamConfiguration.preservesAspectRatio (true/false; macOS 14+; omit to keep native default)
  --quality, -q <m>   automatic|best|nominal (SCStreamConfiguration.captureResolution; macOS 14+; default automatic)
  --keep-temp         Keep AVI and WAV files after mux
''');
}

Future<String?> _resolveFfmpeg() async {
  const candidates = [
    'ffmpeg',
    '/opt/homebrew/bin/ffmpeg',
    '/usr/local/bin/ffmpeg',
  ];
  for (final cmd in candidates) {
    try {
      final r = await Process.run(cmd, ['-hide_banner', '-version']);
      if (r.exitCode == 0) {
        return cmd;
      }
    } on Object {
      continue;
    }
  }
  return null;
}

Future<int> _runFfmpeg({
  required String ffmpegPath,
  required File avi,
  required File systemWav,
  required File micWav,
  required File mp4Out,
  required bool hasSystemAudio,
  required bool hasMicAudio,
}) async {
  final args = <String>[
    '-y',
    '-hide_banner',
    '-loglevel',
    'error',
    '-i',
    avi.path,
  ];

  var sysIdx = -1;
  var micIdx = -1;
  var nextInput = 1;

  final sysReady =
      hasSystemAudio && systemWav.existsSync() && systemWav.lengthSync() > 0;
  final micReady =
      hasMicAudio && micWav.existsSync() && micWav.lengthSync() > 0;

  if (sysReady) {
    args.addAll(['-i', systemWav.path]);
    sysIdx = nextInput++;
  }
  if (micReady) {
    args.addAll(['-i', micWav.path]);
    micIdx = nextInput++;
  }

  if (sysIdx >= 0 && micIdx >= 0) {
    final amix = '[$sysIdx:a][$micIdx:a]amix=inputs=2:duration=longest:'
        'dropout_transition=0[aout]';
    args.addAll([
      '-filter_complex',
      amix,
      '-map',
      '0:v',
      '-map',
      '[aout]',
      '-c:v',
      'libx264',
      '-preset',
      'fast',
      '-crf',
      '20',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      mp4Out.path,
    ]);
  } else if (sysIdx >= 0) {
    args.addAll([
      '-map',
      '0:v',
      '-map',
      '$sysIdx:a',
      '-c:v',
      'libx264',
      '-preset',
      'fast',
      '-crf',
      '20',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      mp4Out.path,
    ]);
  } else if (micIdx >= 0) {
    args.addAll([
      '-map',
      '0:v',
      '-map',
      '$micIdx:a',
      '-c:v',
      'libx264',
      '-preset',
      'fast',
      '-crf',
      '20',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      mp4Out.path,
    ]);
  } else {
    args.addAll([
      '-map',
      '0:v',
      '-an',
      '-c:v',
      'libx264',
      '-preset',
      'fast',
      '-crf',
      '20',
      '-pix_fmt',
      'yuv420p',
      mp4Out.path,
    ]);
  }

  final r = await Process.run(ffmpegPath, args);
  if (r.exitCode != 0) {
    final err = r.stderr;
    if (err is List<int>) {
      stderr.add(err);
    } else if (err is String && err.isNotEmpty) {
      stderr.write(err);
    }
  }
  return r.exitCode;
}
