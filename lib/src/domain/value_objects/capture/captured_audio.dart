import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A single audio buffer from a capture stream.
///
/// Contains raw PCM data. Format is typically Float32 (`format == 'f32'`) or
/// Int16 (`format == 's16'`) from ScreenCaptureKit.
///
/// Ref: https://developer.apple.com/documentation/screencapturekit/scstreamoutputtype/audio
@immutable
class CapturedAudio {
  /// Creates a [CapturedAudio] with the given PCM data and format.
  const CapturedAudio({
    required this.pcmData,
    required this.sampleRate,
    required this.channelCount,
    required this.format,
  });

  /// Raw PCM audio bytes (interleaved channels).
  final Uint8List pcmData;

  /// Sample rate in Hz (e.g. 48000).
  final double sampleRate;

  /// Number of channels (e.g. 2 for stereo).
  final int channelCount;

  /// Format identifier: `f32` (float32), `s16` (int16), or `raw`.
  final String format;
}
