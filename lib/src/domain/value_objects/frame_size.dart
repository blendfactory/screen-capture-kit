/// Size in pixels (width × height).
extension type FrameSize((int, int) value) {
  /// Creates a [FrameSize] from width and height.
  FrameSize.fromWH(int width, int height) : value = (width, height);

  /// Width in pixels.
  int get width => value.$1;

  /// Height in pixels.
  int get height => value.$2;
}
