import 'package:meta/meta.dart';

/// Rectangle in screen points.
///
/// Represents a region with origin (x, y) and size (width, height).
@immutable
class PixelRect {
  /// Creates a [PixelRect] from its components.
  const PixelRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// X coordinate of the origin.
  final double x;

  /// Y coordinate of the origin.
  final double y;

  /// Width of the rectangle.
  final double width;

  /// Height of the rectangle.
  final double height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PixelRect &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() =>
      'PixelRect(x: $x, y: $y, width: $width, height: $height)';
}
