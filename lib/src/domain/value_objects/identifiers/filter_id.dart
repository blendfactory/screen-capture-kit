/// Identifier for an opaque native content filter.
///
/// Must be a positive integer. Release the native filter with the
/// application `releaseFilter` when the filter is no longer needed.
extension type FilterId._(int value) {
  /// Creates a [FilterId] for a valid native filter handle.
  ///
  /// Throws [ArgumentError] if [value] is not positive.
  factory FilterId(int value) {
    if (value <= 0) {
      throw ArgumentError.value(
        value,
        'value',
        'FilterId must be positive',
      );
    }
    return FilterId._(value);
  }
}
