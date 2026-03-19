import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'package:screen_capture_kit/src/domain/value_objects/geometry/frame_size.dart';

/// A single frame from a capture stream.
///
/// Contains BGRA pixel data (blue, green, red, alpha per pixel).
@immutable
class CapturedFrame {
  /// Creates a [CapturedFrame] with the given data and dimensions.
  const CapturedFrame({
    required this.bgraData,
    required this.size,
    required this.bytesPerRow,
  });

  /// Raw BGRA pixel data.
  final Uint8List bgraData;

  /// Frame dimensions in pixels.
  final FrameSize size;

  /// Bytes per row (stride).
  final int bytesPerRow;
}
