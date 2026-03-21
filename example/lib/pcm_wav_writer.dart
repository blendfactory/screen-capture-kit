// Optional WAV header fields are assigned together on first [add].
// ignore_for_file: use_late_for_private_fields_and_variables

import 'dart:io';
import 'dart:typed_data';

import 'package:screen_capture_kit/screen_capture_kit.dart';

/// Core Audio / WAV IEEE float PCM is little-endian. Replace non-finite
/// samples and clamp to **[-1, 1]** so ffmpeg AAC does not fail on extreme
/// float values.
Uint8List _coerceFiniteFloat32Pcm(Uint8List pcm) {
  if (pcm.length < 4 || pcm.length % 4 != 0) {
    return pcm;
  }
  final bd = ByteData.sublistView(pcm);
  var dirty = false;
  for (var i = 0; i < pcm.length; i += 4) {
    final v = bd.getFloat32(i, Endian.little);
    if (!v.isFinite || v > 1.0 || v < -1.0) {
      dirty = true;
      break;
    }
  }
  if (!dirty) {
    return pcm;
  }
  final out = Uint8List(pcm.length);
  final outBd = ByteData.sublistView(out);
  for (var i = 0; i < pcm.length; i += 4) {
    var v = bd.getFloat32(i, Endian.little);
    if (!v.isFinite) {
      v = 0.0;
    } else if (v > 1.0) {
      v = 1.0;
    } else if (v < -1.0) {
      v = -1.0;
    }
    outBd.setFloat32(i, v, Endian.little);
  }
  return out;
}

/// Appends interleaved PCM from [CapturedAudio] into a WAV file (sync I/O).
class PcmWavWriter {
  PcmWavWriter(this._file);

  final File _file;

  RandomAccessFile? _raf;
  static const _headerBytes = 44;
  var _pcmBytes = 0;

  int? _channels;
  int? _sampleRate;
  int? _bitsPerSample;
  int? _audioFormat;

  int get pcmBytesWritten => _pcmBytes;

  /// Channel count after the first [add], or null if no PCM yet.
  int? get channelCount => _channels;

  /// Sample rate after the first [add], or null if no PCM yet.
  int? get sampleRate => _sampleRate;

  /// Bits per sample after the first [add], or null if no PCM yet.
  int? get bitsPerSample => _bitsPerSample;

  void add(CapturedAudio chunk) {
    _raf ??= _file.openSync(mode: FileMode.write);

    if (_channels == null) {
      final fmt = chunk.format;
      if (fmt == 'f32') {
        _audioFormat = 3;
        _bitsPerSample = 32;
      } else if (fmt == 's16') {
        _audioFormat = 1;
        _bitsPerSample = 16;
      } else {
        throw StateError(
          'Unsupported CapturedAudio format "$fmt" (expected f32 or s16).',
        );
      }
      _channels = chunk.channelCount;
      _sampleRate = chunk.sampleRate.round();
      _writeHeaderPlaceholder();
    } else {
      _assertCompatible(chunk);
    }

    if (chunk.pcmData.isNotEmpty) {
      final bytes = chunk.format == 'f32'
          ? _coerceFiniteFloat32Pcm(chunk.pcmData)
          : chunk.pcmData;
      _raf!.writeFromSync(bytes);
      _pcmBytes += bytes.length;
    }
  }

  /// Opens the file and writes the WAV header placeholder from [chunk] without
  /// appending PCM. Use before [padSilenceToPcmBytesSync] when leading silence
  /// precedes the first audio payload.
  void ensureFormatFromChunk(CapturedAudio chunk) {
    _raf ??= _file.openSync(mode: FileMode.write);

    if (_channels == null) {
      final fmt = chunk.format;
      if (fmt == 'f32') {
        _audioFormat = 3;
        _bitsPerSample = 32;
      } else if (fmt == 's16') {
        _audioFormat = 1;
        _bitsPerSample = 16;
      } else {
        throw StateError(
          'Unsupported CapturedAudio format "$fmt" (expected f32 or s16).',
        );
      }
      _channels = chunk.channelCount;
      _sampleRate = chunk.sampleRate.round();
      _writeHeaderPlaceholder();
    } else {
      _assertCompatible(chunk);
    }
  }

  /// Appends zero PCM bytes so that [_pcmBytes] is at least [targetPcmBytes],
  /// rounded up to a full frame ([block align]). Requires that [add] has run
  /// at least once so format and channel layout are known.
  void padSilenceToPcmBytesSync(int targetPcmBytes) {
    if (_raf == null || _channels == null || _bitsPerSample == null) {
      throw StateError(
        'padSilenceToPcmBytesSync: call add() first to establish WAV format.',
      );
    }
    if (targetPcmBytes <= _pcmBytes) {
      return;
    }
    var delta = targetPcmBytes - _pcmBytes;
    final blockAlign = _channels! * (_bitsPerSample! ~/ 8);
    final rem = delta % blockAlign;
    if (rem != 0) {
      delta += blockAlign - rem;
    }
    if (delta <= 0) {
      return;
    }
    _raf!.writeFromSync(Uint8List(delta));
    _pcmBytes += delta;
  }

  void _assertCompatible(CapturedAudio chunk) {
    if (chunk.channelCount != _channels) {
      throw StateError(
        'Channel count changed from $_channels to ${chunk.channelCount}.',
      );
    }
    if (chunk.sampleRate.round() != _sampleRate) {
      throw StateError(
        'Sample rate changed from $_sampleRate to ${chunk.sampleRate}.',
      );
    }
    final fmt = chunk.format;
    final expectedBits = fmt == 'f32' ? 32 : 16;
    if (expectedBits != _bitsPerSample) {
      throw StateError('Audio format changed mid-stream.');
    }
  }

  void _writeHeaderPlaceholder() {
    final raf = _raf!;
    raf.setPositionSync(0);
    raf.writeFromSync(Uint8List(_headerBytes));
  }

  /// Writes the WAV header and closes. Deletes the file when no PCM exists.
  void finalizeSync() {
    final raf = _raf;
    if (raf == null) {
      return;
    }

    if (_channels != null && _pcmBytes > 0) {
      final blockAlign = _channels! * (_bitsPerSample! ~/ 8);
      final byteRate = _sampleRate! * blockAlign;
      final fileSize = _headerBytes + _pcmBytes;
      final riffChunkSize = fileSize - 8;

      final bd = ByteData(_headerBytes);
      var o = 0;
      void wFourCC(String s) {
        for (var i = 0; i < 4; i++) {
          bd.setUint8(o + i, s.codeUnitAt(i));
        }
        o += 4;
      }

      wFourCC('RIFF');
      bd.setUint32(o, riffChunkSize, Endian.little);
      o += 4;
      wFourCC('WAVE');
      wFourCC('fmt ');
      bd.setUint32(o, 16, Endian.little);
      o += 4;
      bd.setUint16(o, _audioFormat!, Endian.little);
      o += 2;
      bd.setUint16(o, _channels!, Endian.little);
      o += 2;
      bd.setUint32(o, _sampleRate!, Endian.little);
      o += 4;
      bd.setUint32(o, byteRate, Endian.little);
      o += 4;
      bd.setUint16(o, blockAlign, Endian.little);
      o += 2;
      bd.setUint16(o, _bitsPerSample!, Endian.little);
      o += 2;
      wFourCC('data');
      bd.setUint32(o, _pcmBytes, Endian.little);

      raf.setPositionSync(0);
      raf.writeFromSync(bd.buffer.asUint8List());
    } else {
      raf.closeSync();
      _raf = null;
      if (_file.existsSync()) {
        _file.deleteSync();
      }
      return;
    }

    raf.closeSync();
    _raf = null;
  }

  bool get hasAudio => _pcmBytes > 0;
}

/// Writes PCM into a WAV using `CMSampleBuffer` presentation timestamps so
/// system audio and microphone line up on a shared anchor (same SCStream
/// timebase). Falls back to sequential [PcmWavWriter] behavior when timestamps
/// are missing.
class TimelinePcmWavWriter {
  TimelinePcmWavWriter(File file) : _inner = PcmWavWriter(file);

  final PcmWavWriter _inner;
  final List<CapturedAudio> _pending = [];
  double? _anchorSec;
  var _samplesWritten = 0;
  var _wallEndSec = 0.0;
  var _sequential = false;
  var _anchorLocked = false;

  /// Latest end time seen on this stream: PTS + duration (or inferred length).
  double get wallClockEndSec => _wallEndSec;

  /// True when buffers were placed using a timeline anchor (not sequential).
  bool get usesTimeline => _anchorLocked && !_sequential;

  void ingest(CapturedAudio chunk) {
    if (_sequential) {
      _inner.add(chunk);
      return;
    }
    if (chunk.presentationTimeSeconds == null) {
      disableTimeline();
      _inner.add(chunk);
      return;
    }
    if (!_anchorLocked) {
      _pending.add(chunk);
      return;
    }
    _writeAligned(chunk);
  }

  /// Call after the first PTS is known on both streams (minimum of the two).
  void setTimelineAnchorSec(double anchorSec) {
    if (_sequential || _anchorLocked) {
      return;
    }
    _anchorSec = anchorSec;
    _anchorLocked = true;
    _pending.sort(
      (a, b) => a.presentationTimeSeconds!.compareTo(
        b.presentationTimeSeconds!,
      ),
    );
    _pending.forEach(_writeAligned);
    _pending.clear();
  }

  /// Switches to plain append order (used when timing is unavailable).
  void disableTimeline() {
    if (_sequential) {
      return;
    }
    _sequential = true;
    _pending.forEach(_inner.add);
    _pending.clear();
  }

  /// Pads silence so this track ends at [endSec] on the shared timeline.
  void padEndToTimeSec(double endSec) {
    if (_sequential || _anchorSec == null || !_anchorLocked) {
      return;
    }
    final rate = _inner.sampleRate;
    final ch = _inner.channelCount;
    final bits = _inner.bitsPerSample;
    if (rate == null || ch == null || bits == null) {
      return;
    }
    _syncSamplesWrittenFromInner();
    final target = ((endSec - _anchorSec!) * rate).round();
    if (target <= _samplesWritten) {
      return;
    }
    final padFrames = target - _samplesWritten;
    final blockAlign = ch * (bits ~/ 8);
    _inner.padSilenceToPcmBytesSync(
      _inner.pcmBytesWritten + padFrames * blockAlign,
    );
    _samplesWritten = target;
  }

  void finalizeSync() => _inner.finalizeSync();

  /// For legacy byte-ratio padding when timeline metadata is missing.
  void padSilenceToPcmBytesSync(int targetPcmBytes) {
    _inner.padSilenceToPcmBytesSync(targetPcmBytes);
  }

  bool get hasAudio => _inner.hasAudio;

  int? get channelCount => _inner.channelCount;

  int get pcmBytesWritten => _inner.pcmBytesWritten;

  /// Sample index at end of PCM data (excludes WAV header); derived from the
  /// wrapped [PcmWavWriter]'s `pcmBytesWritten` and frame size when known.
  void _syncSamplesWrittenFromInner() {
    final ch = _inner.channelCount;
    final bits = _inner.bitsPerSample;
    if (ch == null || bits == null) {
      return;
    }
    final blockAlign = ch * (bits ~/ 8);
    if (blockAlign <= 0) {
      return;
    }
    _samplesWritten = _inner.pcmBytesWritten ~/ blockAlign;
  }

  void _writeAligned(CapturedAudio c) {
    _syncSamplesWrittenFromInner();
    final anchor = _anchorSec!;
    final t = c.presentationTimeSeconds!;
    final rate = c.sampleRate;
    var startSample = ((t - anchor) * rate).round();
    if (startSample < 0) {
      startSample = 0;
    }

    final pcmFrames = _pcmFramesInChunk(c);
    if (pcmFrames <= 0 && c.pcmData.isEmpty) {
      _noteWallEnd(c, 0);
      return;
    }

    if (startSample < _samplesWritten) {
      final skip = _samplesWritten - startSample;
      if (skip >= pcmFrames) {
        _noteWallEnd(c, pcmFrames);
        return;
      }
      final bps = _bytesPerSample(c.format);
      final skipBytes = skip * c.channelCount * bps;
      final trimmed = c.pcmData.sublist(skipBytes);
      final adj = CapturedAudio(
        pcmData: trimmed,
        sampleRate: c.sampleRate,
        channelCount: c.channelCount,
        format: c.format,
        frameCount: pcmFrames - skip,
        presentationTimeSeconds: c.presentationTimeSeconds,
        durationSeconds: c.durationSeconds,
      );
      _writeAlignedAt(adj, _samplesWritten);
      return;
    }

    if (startSample > _samplesWritten) {
      _inner.ensureFormatFromChunk(c);
      final padFrames = startSample - _samplesWritten;
      final ch = c.channelCount;
      final bps = _bytesPerSample(c.format);
      final blockAlign = ch * bps;
      _inner.padSilenceToPcmBytesSync(
        _inner.pcmBytesWritten + padFrames * blockAlign,
      );
      _syncSamplesWrittenFromInner();
    }

    _writeAlignedAt(c, startSample);
  }

  void _writeAlignedAt(CapturedAudio c, int startSample) {
    if (c.pcmData.isNotEmpty) {
      _inner.add(c);
    }
    _syncSamplesWrittenFromInner();
    _noteWallEnd(c, _pcmFramesInChunk(c));
  }

  /// [framesWritten] must reflect **actual** PCM in the chunk (not native
  /// `numSamples` when it exceeds bytes), so wall-clock end and tail padding
  /// match the file length.
  void _noteWallEnd(CapturedAudio c, int framesWritten) {
    final t = c.presentationTimeSeconds;
    if (t == null) {
      return;
    }
    var end = t;
    if (c.durationSeconds != null && c.durationSeconds! > 0) {
      end = t + c.durationSeconds!;
    } else if (framesWritten > 0 && c.sampleRate > 0) {
      end = t + framesWritten / c.sampleRate;
    }
    if (end > _wallEndSec) {
      _wallEndSec = end;
    }
  }

  static int _pcmFramesInChunk(CapturedAudio c) {
    final bps = _bytesPerSample(c.format);
    final bpf = c.channelCount * bps;
    if (bpf <= 0) {
      return 0;
    }
    return c.pcmData.length ~/ bpf;
  }

  static int _bytesPerSample(String format) {
    if (format == 'f32') {
      return 4;
    }
    if (format == 's16') {
      return 2;
    }
    return 0;
  }
}

/// Locks a shared timeline anchor from the first PTS on each stream, then
/// flushes pending buffers into [TimelinePcmWavWriter]s.
class DualAudioWavTimelineCoordinator {
  DualAudioWavTimelineCoordinator({
    required this.system,
    required this.microphone,
  });

  final TimelinePcmWavWriter system;
  final TimelinePcmWavWriter microphone;

  double? _sysFirstPts;
  double? _micFirstPts;
  var _timelineDisabled = false;
  var _locked = false;
  double? _anchorSec;

  void addSystem(CapturedAudio c) {
    _ingest(c, isSystem: true);
  }

  void addMicrophone(CapturedAudio c) {
    _ingest(c, isSystem: false);
  }

  void _ingest(CapturedAudio c, {required bool isSystem}) {
    if (c.presentationTimeSeconds == null) {
      _disableAllTimelines();
    } else if (!_timelineDisabled && !_locked) {
      if (isSystem) {
        _sysFirstPts ??= c.presentationTimeSeconds;
      } else {
        _micFirstPts ??= c.presentationTimeSeconds;
      }
    }

    if (isSystem) {
      system.ingest(c);
    } else {
      microphone.ingest(c);
    }

    _tryLockAnchor();
  }

  /// Call before finalizing writers so pending buffers are flushed and streams
  /// share a common end time when timeline mode applied.
  void prepareForFinalize() {
    if (_locked && !_timelineDisabled) {
      padStreamsToCommonEnd();
      return;
    }
    if (!_timelineDisabled) {
      _disableAllTimelines();
    }
  }

  void _disableAllTimelines() {
    if (_timelineDisabled) {
      return;
    }
    _timelineDisabled = true;
    system.disableTimeline();
    microphone.disableTimeline();
  }

  void _tryLockAnchor() {
    if (_locked || _timelineDisabled) {
      return;
    }
    final a = _sysFirstPts;
    final b = _micFirstPts;
    if (a == null || b == null) {
      return;
    }
    _anchorSec = a <= b ? a : b;
    _locked = true;
    system.setTimelineAnchorSec(_anchorSec!);
    microphone.setTimelineAnchorSec(_anchorSec!);
  }

  /// Pads the shorter stream so both WAVs extend to the later wall-clock end
  /// (`wallClockEndSec` on each [TimelinePcmWavWriter]).
  void padStreamsToCommonEnd() {
    if (!_locked || _timelineDisabled || _anchorSec == null) {
      return;
    }
    final end = system.wallClockEndSec > microphone.wallClockEndSec
        ? system.wallClockEndSec
        : microphone.wallClockEndSec;
    if (end <= 0) {
      return;
    }
    system.padEndToTimeSec(end);
    microphone.padEndToTimeSec(end);
  }

  /// True when timeline alignment was applied (not byte-ratio fallback).
  bool get lockedWithTimeline =>
      _locked &&
      !_timelineDisabled &&
      system.usesTimeline &&
      microphone.usesTimeline;

  bool get timelineDisabled => _timelineDisabled;
}
