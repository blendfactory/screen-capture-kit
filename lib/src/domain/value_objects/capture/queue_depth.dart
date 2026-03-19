/// @docImport 'package:screen_capture_kit/src/domain/value_objects/capture/stream_configuration.dart';
library;

import 'package:meta/meta.dart';

/// Target capture stream queue depth.
///
/// Valid range: `1..8` (inclusive).
///
/// Invalid values throw [ArgumentError].
@immutable
class QueueDepth {
  /// Creates a [QueueDepth] with the given value.
  ///
  /// Throws [ArgumentError] when `value` is outside `1..8`.
  factory QueueDepth(int value) {
    if (value < 1 || value > 8) {
      throw ArgumentError(
        'QueueDepth must be between 1 and 8 (inclusive); got $value.',
      );
    }
    return QueueDepth._(value);
  }

  const QueueDepth._(this.value);

  /// Default queue depth used when the caller does not specify one.
  const QueueDepth.depth5() : value = 5;

  /// The validated queue depth value.
  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QueueDepth && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'QueueDepth($value)';
}
