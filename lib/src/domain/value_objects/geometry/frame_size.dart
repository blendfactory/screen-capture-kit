import 'package:meta/meta.dart';

/// Size in pixels (width × height).
@immutable
class FrameSize {
  /// Creates a [FrameSize] from width and height.
  const FrameSize({
    required this.width,
    required this.height,
  });

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrameSize &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'FrameSize(width: $width, height: $height)';
}
