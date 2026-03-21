/// Identifier for a display device.
///
/// Wraps the native display identifier ([CGDirectDisplayID](https://developer.apple.com/documentation/coregraphics/cgdirectdisplayid))
/// as a distinct type. Must be positive.
extension type DisplayId._(int value) {
  /// Creates a [DisplayId] with the given Core Graphics display identifier.
  ///
  /// Throws [ArgumentError] if [value] is not positive.
  factory DisplayId(int value) {
    if (value <= 0) {
      throw ArgumentError.value(
        value,
        'value',
        'DisplayId must be positive',
      );
    }
    return DisplayId._(value);
  }
}
