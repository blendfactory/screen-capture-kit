/// Identifier for an opaque native content filter.
///
/// Must be a positive integer; creation sites should enforce this invariant.
extension type FilterId(int value) {
  /// The underlying filter identifier.
  int get filterId => value;
}
