/// Identifier for an opaque native content filter.
///
/// Must be a positive integer; creation sites enforce this invariant.
extension type const FilterId(int value) {
  /// The underlying filter identifier.
  int get filterId => value;
}
