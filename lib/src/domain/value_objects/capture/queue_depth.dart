/// Target capture stream queue depth.
extension type const QueueDepth._(int value) {
  /// Creates a [QueueDepth] with the given value.
  ///
  /// Throws [ArgumentError] if the value is outside the range `1..8`.
  factory QueueDepth(int value) {
    if (value < 1 || value > 8) {
      throw ArgumentError(
        'QueueDepth must be between 1 and 8 (inclusive); got $value.',
      );
    }
    return QueueDepth._(value);
  }

  /// Default queue depth used when the caller does not specify one.
  const QueueDepth.depth5() : value = 5;
}
