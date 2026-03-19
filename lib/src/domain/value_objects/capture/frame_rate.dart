/// Target capture frame rate in FPS.
extension type const FrameRate._(int value) {
  /// Creates a [FrameRate] with the given value.
  ///
  /// Throws [ArgumentError] if the value is outside the range `1..120`.
  factory FrameRate(int value) {
    if (value < 1 || value > 120) {
      throw ArgumentError(
        'FrameRate must be between 1 and 120 (inclusive); got $value.',
      );
    }
    return FrameRate._(value);
  }

  /// Default frame rate used when the caller does not specify one.
  const FrameRate.fps60() : value = 60;
}
