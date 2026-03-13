import 'dart:typed_data';

/// A single frame from a capture stream.
///
/// Contains BGRA pixel data (blue, green, red, alpha per pixel).
class CapturedFrame {
  /// Creates a [CapturedFrame] with the given data and dimensions.
  const CapturedFrame({
    required this.bgraData,
    required this.width,
    required this.height,
    required this.bytesPerRow,
  });

  /// Raw BGRA pixel data.
  final Uint8List bgraData;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// Bytes per row (stride).
  final int bytesPerRow;
}
