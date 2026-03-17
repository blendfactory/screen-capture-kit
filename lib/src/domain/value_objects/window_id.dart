/// Identifier for a window.
///
/// Wraps the native window identifier as a distinct type.
extension type WindowId(int value) {
  /// The underlying window identifier.
  int get windowId => value;
}
