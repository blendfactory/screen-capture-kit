/// Reported display refresh rate in whole hertz (e.g. 60, 120).
///
/// Populated from CoreGraphics `CGDisplayModeGetRefreshRate` via shareable
/// content JSON. Use `DisplayRefreshRate.unknown()` when the OS does not report
/// a usable value.
extension type const DisplayRefreshRate._(int value) {
  /// Creates a known refresh rate in Hz.
  ///
  /// Throws [ArgumentError] if [hz] is outside `1..480`.
  factory DisplayRefreshRate(int hz) {
    if (hz < 1 || hz > 480) {
      throw ArgumentError(
        'DisplayRefreshRate must be between 1 and 480 (inclusive); '
        'use DisplayRefreshRate.unknown() for unavailable. Got $hz.',
      );
    }
    return DisplayRefreshRate._(hz);
  }

  /// Sentinel when the refresh rate is unavailable or unknown (0 Hz).
  const DisplayRefreshRate.unknown() : value = 0;

  /// Builds from shareable-content JSON (`refreshRate`) or similar numeric API
  /// values.
  ///
  /// Null, non-finite, non-positive, or out-of-range values yield
  /// `DisplayRefreshRate.unknown()`.
  factory DisplayRefreshRate.fromNum(num? raw) {
    if (raw == null || !raw.isFinite) {
      return const DisplayRefreshRate.unknown();
    }
    final rounded = raw.round();
    if (rounded < 1 || rounded > 480) {
      return const DisplayRefreshRate.unknown();
    }
    return DisplayRefreshRate._(rounded);
  }

  /// Whether the OS reported a positive refresh rate in Hz.
  bool get isKnown => value > 0;
}
