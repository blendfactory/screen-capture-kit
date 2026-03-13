import 'dart:typed_data';

/// A captured screenshot image.
///
/// Contains PNG-encoded image data and dimensions.
class CapturedImage {
  /// Creates a [CapturedImage] with the given data and dimensions.
  const CapturedImage({
    required this.pngData,
    required this.width,
    required this.height,
  });

  /// The PNG-encoded image bytes.
  final Uint8List pngData;

  /// The width of the captured image in pixels.
  final int width;

  /// The height of the captured image in pixels.
  final int height;
}
