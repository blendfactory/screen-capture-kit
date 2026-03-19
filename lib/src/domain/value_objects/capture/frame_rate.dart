/// @docImport 'package:screen_capture_kit/src/domain/value_objects/capture/stream_configuration.dart';
library;

import 'package:meta/meta.dart';

/// Target capture frame rate in FPS.
///
/// Valid range: `1..120` (inclusive).
///
/// Invalid values throw [ArgumentError].
@immutable
class FrameRate {
  /// Creates a [FrameRate] with the given FPS value.
  ///
  /// Throws [ArgumentError] when `value` is outside `1..120`.
  factory FrameRate(int value) {
    if (value < 1 || value > 120) {
      throw ArgumentError(
        'FrameRate must be between 1 and 120 (inclusive); got $value.',
      );
    }
    return FrameRate._(value);
  }

  const FrameRate._(this.value);

  /// Default frame rate used when the caller does not specify one.
  const FrameRate.fps60() : value = 60;

  /// The validated FPS value.
  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FrameRate && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FrameRate($value fps)';
}
