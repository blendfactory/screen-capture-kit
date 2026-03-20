import 'dart:async';
import 'dart:io';

import 'package:screen_capture_kit/screen_capture_kit.dart';
import 'package:screen_capture_kit_example/avi_isolate_recorder.dart';
import 'package:screen_capture_kit_example/pcm_wav_writer.dart';

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
    exitCode = 69; // EX_UNAVAILABLE
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
    stdout.writeln(
      'Capturing system audio + microphone (mic requires macOS 15+). '
      'Grant Microphone access if prompted.',
    );

    final outWidth = parsed.width ?? display.width;
    final outHeight = parsed.height ?? display.height;
    if (outWidth <= 0 || outHeight <= 0) {
      stderr.writeln('Invalid frame size: ${outWidth}x$outHeight');
      exitCode = 64;
      return;
    }

    if (!parsed.outputDir.existsSync()) {
      parsed.outputDir.createSync(recursive: true);
    }

    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final base = 'record_display_av_${display.displayId.value}_'
        '${outWidth}x${outHeight}_$ts';
    final dir = parsed.outputDir.path;
    final aviFile = File('$dir/${base}_video.avi');
    final sysWavFile = File('$dir/${base}_system.wav');
    final micWavFile = File('$dir/${base}_mic.wav');
    final mp4File = File('$dir/$base.mp4');

    filter = await kit.createDisplayFilter(
      display,
    );

    final capture = kit.startCaptureStreamWithUpdater(
      filter!,
      frameSize: FrameSize(width: outWidth, height: outHeight),
      frameRate: FrameRate(fps),
      pixelFormat: cvPixelFormatType32Bgra,
      capturesAudio: true,
      excludesCurrentProcessAudio: true,
      captureMicrophone: true,
    );

    final audioStream = capture.audioStream;
    final micStream = capture.microphoneStream;
    if (audioStream == null) {
      stderr
          .writeln('Audio stream is unavailable (capturesAudio unsupported?).');
      exitCode = 1;
      return;
    }
    if (micStream == null) {
      stderr.writeln(
        'Microphone stream is unavailable. Use a macOS 15+ system with '
        'Microphone permission.',
      );
      exitCode = 1;
      return;
    }

    final sysWriter = PcmWavWriter(sysWavFile);
    final micWriter = PcmWavWriter(micWavFile);

    StreamSubscription<CapturedAudio>? sysSub;
    StreamSubscription<CapturedAudio>? micSub;

    Object? audioErr;
    StackTrace? audioSt;
    void logAudioErr(Object e, StackTrace st) {
      audioErr ??= e;
      audioSt ??= st;
    }

    sysSub = audioStream.listen(
      (chunk) {
        try {
          sysWriter.add(chunk);
        } on Object catch (e, st) {
          logAudioErr(e, st);
        }
      },
      onError: logAudioErr,
    );

    micSub = micStream.listen(
      (chunk) {
        try {
          micWriter.add(chunk);
        } on Object catch (e, st) {
          logAudioErr(e, st);
        }
      },
      onError: logAudioErr,
    );

    Future<void> sealAudio() async {
      await sysSub?.cancel();
      await micSub?.cancel();
      sysSub = null;
      micSub = null;

      // ScreenCaptureKit often delivers fewer samples per mic buffer than per
      // system-audio buffer while callbacks stay paired. Pad mic PCM so WAV
      // duration matches system audio (stereo vs mono f32: mic bytes ~ sys/2).
      if (sysWriter.hasAudio && micWriter.hasAudio) {
        final sysCh = sysWriter.channelCount;
        final micCh = micWriter.channelCount;
        final sysB = sysWriter.pcmBytesWritten;
        final micB = micWriter.pcmBytesWritten;
        var micPadTarget = 0;
        if (sysCh == 2 && micCh == 1) {
          micPadTarget = sysB ~/ 2;
        } else if (sysCh != null && micCh != null && sysCh == micCh) {
          micPadTarget = sysB;
        }
        if (micPadTarget > 0 && micB < micPadTarget) {
          micWriter.padSilenceToPcmBytesSync(micPadTarget);
        }
      }

      sysWriter.finalizeSync();
      micWriter.finalizeSync();
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
      hasSystemAudio: sysWriter.hasAudio,
      hasMicAudio: micWriter.hasAudio,
    );

    if (muxCode != 0) {
      stderr.writeln('ffmpeg exited with code $muxCode.');
      stderr.writeln(
        'Intermediate files kept: ${aviFile.path}, '
        '${sysWavFile.path}, ${micWavFile.path}',
      );
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
        'Kept intermediates: ${aviFile.path}, ${sysWavFile.path}, '
        '${micWavFile.path}',
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

class _ParsedArgs {
  const _ParsedArgs({
    required this.outputDir,
    required this.fps,
    this.displayOneBased,
    this.durationSeconds,
    this.width,
    this.height,
    this.keepTemp = false,
  });

  final Directory outputDir;
  final int? displayOneBased;
  final double? durationSeconds;
  final int fps;
  final int? width;
  final int? height;
  final bool keepTemp;
}

_ParsedArgs? _parseArgs(List<String> args) {
  Directory? outDir;
  int? displayOneBased;
  double? durationSeconds;
  var fps = 30;
  int? width;
  int? height;
  var keepTemp = false;

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
    if (a == '--keep-temp') {
      keepTemp = true;
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
    keepTemp: keepTemp,
  );
}

void _printUsage() {
  stderr.writeln('''
Record a display with system audio and microphone to H.264/AAC MP4 via ffmpeg.

Intermediate: uncompressed AVI (BGRA) + PCM WAV (system + mic), then muxed.

Requirements:
  ffmpeg on PATH (e.g. brew install ffmpeg)
  macOS 13+ for system audio capture; macOS 15+ for microphone via ScreenCaptureKit

Usage:
  dart run bin/record_display_with_audio.dart --out <dir> [options]
  dart run bin/record_display_with_audio.dart <dir> [options]

Options:
  --out, -o <dir>    Output directory (created if missing)
  --display, -d <n>  1-based display index (omit → interactive)
  --duration, -t <s> Stop after seconds (omit → Ctrl+C)
  --fps <n>          Video FPS / AVI timebase (default 30; 1..120)
  --width, --height  Output size (default: display size)
  --keep-temp        Keep AVI and WAV files after mux
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

/// [hasSystemAudio] / [hasMicAudio] reflect whether WAV writers received PCM.
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
