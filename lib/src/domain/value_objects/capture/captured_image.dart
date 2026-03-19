import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'package:screen_capture_kit/src/domain/value_objects/geometry/frame_size.dart';

/// A captured screenshot image.
///
/// Contains PNG-encoded image data and dimensions.
@immutable
class CapturedImage {
  /// Creates a [CapturedImage] with the given data and dimensions.
  const CapturedImage({
    required this.pngData,
    required this.size,
  });

  /// The PNG-encoded image bytes.
  final Uint8List pngData;

  /// The dimensions of the captured image in pixels.
  final FrameSize size;

  /// The width of the captured image in pixels.
  int get width => size.width;

  /// The height of the captured image in pixels.
  int get height => size.height;
}
