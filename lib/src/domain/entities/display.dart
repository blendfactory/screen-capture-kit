import 'package:meta/meta.dart';

import 'package:screen_capture_kit/src/domain/value_objects/capture/display_refresh_rate.dart';
import 'package:screen_capture_kit/src/domain/value_objects/geometry/frame_size.dart';
import 'package:screen_capture_kit/src/domain/value_objects/identifiers/display_id.dart';

/// A display device available for capture.
///
/// Maps to [SCDisplay](https://developer.apple.com/documentation/screencapturekit/scdisplay).
@immutable
class Display {
  /// Creates a [Display] with the given properties.
  const Display({
    required this.displayId,
    required this.size,
    this.refreshRate = const DisplayRefreshRate.unknown(),
  });

  /// The display identifier.
  final DisplayId displayId;

  /// The size of the display in pixels.
  final FrameSize size;

  /// The display's refresh rate in whole Hz when [DisplayRefreshRate.isKnown].
  ///
  /// Obtained via `CGDisplayModeGetRefreshRate` on macOS when loading
  /// shareable content.
  final DisplayRefreshRate refreshRate;

  /// The width of the display in pixels.
  int get width => size.width;

  /// The height of the display in pixels.
  int get height => size.height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Display &&
          runtimeType == other.runtimeType &&
          displayId == other.displayId &&
          size == other.size &&
          refreshRate == other.refreshRate;

  @override
  int get hashCode => Object.hash(displayId, size, refreshRate);

  @override
  String toString() =>
      'Display(displayId: ${displayId.value}, '
      'width: $width, height: $height, '
      'refreshRate: $refreshRate)';
}
