// Optional WAV header fields are assigned together on first [add].
// ignore_for_file: use_late_for_private_fields_and_variables

import 'dart:io';
import 'dart:typed_data';

import 'package:screen_capture_kit/screen_capture_kit.dart';

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
      _raf!.writeFromSync(chunk.pcmData);
      _pcmBytes += chunk.pcmData.length;
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
