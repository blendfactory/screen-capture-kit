/// Rectangle in screen points.
///
/// Represents a region with origin (x, y) and size (width, height).
extension type PixelRect(
  ({double x, double y, double width, double height}) value
) {
  /// Creates a [PixelRect] from its components.
  PixelRect.fromComponents({
    required double x,
    required double y,
    required double width,
    required double height,
  }) : value = (x: x, y: y, width: width, height: height);

  /// X coordinate of the origin.
  double get x => value.x;

  /// Y coordinate of the origin.
  double get y => value.y;

  /// Width of the rectangle.
  double get width => value.width;

  /// Height of the rectangle.
  double get height => value.height;
}
