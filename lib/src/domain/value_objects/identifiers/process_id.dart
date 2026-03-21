/// Identifier for a running process.
///
/// Wraps the native process identifier (PID). Non-negative: `0` may appear
/// when the native layer omits a process id (e.g. owning application on a
/// window snapshot).
extension type ProcessId._(int value) {
  /// Creates a [ProcessId] with the given PID.
  ///
  /// Throws [ArgumentError] if [value] is negative.
  factory ProcessId(int value) {
    if (value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'ProcessId must be non-negative',
      );
    }
    return ProcessId._(value);
  }
}
