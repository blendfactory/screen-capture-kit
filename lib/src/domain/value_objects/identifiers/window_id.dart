/// Identifier for a window.
///
/// Wraps the native window identifier ([CGWindowID](https://developer.apple.com/documentation/coregraphics/cgwindowid))
/// as a distinct type. Must be positive.
extension type WindowId._(int value) {
  /// Creates a [WindowId] with the given window identifier.
  ///
  /// Throws [ArgumentError] if [value] is not positive.
  factory WindowId(int value) {
    if (value <= 0) {
      throw ArgumentError.value(
        value,
        'value',
        'WindowId must be positive',
      );
    }
    return WindowId._(value);
  }
}
