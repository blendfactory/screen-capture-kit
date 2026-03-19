/// Identifier for a running process.
///
/// Wraps the native process identifier as a distinct type.
extension type const ProcessId(int value) {
  /// The underlying process identifier.
  int get processId => value;
}
