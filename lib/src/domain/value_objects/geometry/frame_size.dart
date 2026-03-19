/// @docImport 'package:screen_capture_kit/src/domain/value_objects/capture/stream_configuration.dart';
library;

import 'package:meta/meta.dart';

/// Size in pixels (width × height).
///
/// Use the [FrameSize] factory so values are **non-negative** and either
/// **0×0** or **both dimensions strictly positive** (matches capture-output
/// rules for the native bridge). Invalid combinations throw [ArgumentError].
///
/// [FrameSize.zero] is the canonical 0×0 size (native default output in the
/// bridge).
@immutable
class FrameSize {
  /// Creates a [FrameSize] from width and height.
  factory FrameSize({
    required int width,
    required int height,
  }) {
    if (width < 0 || height < 0) {
      throw ArgumentError(
        'FrameSize width and height must be non-negative',
      );
    }
    if (width == 0 && height == 0) {
      return const FrameSize.zero();
    }
    if (width > 0 && height > 0) {
      return FrameSize._(width: width, height: height);
    }
    throw ArgumentError(
      'FrameSize width and height must be 0x0 (native defaults) or both '
      'dimensions positive; got width=$width, height=$height.',
    );
  }

  /// Internal constructor for [FrameSize].
  const FrameSize._({
    required this.width,
    required this.height,
  });

  /// Zero width and height (native default capture output in the bridge).
  const FrameSize.zero() : width = 0, height = 0;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrameSize &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'FrameSize(width: $width, height: $height)';
}
