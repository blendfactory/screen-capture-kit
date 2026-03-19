/// Identifier for a display device.
///
/// Wraps the native display identifier as a distinct type.
extension type const DisplayId(int value) {
  /// The underlying display identifier.
  int get displayId => value;
}
