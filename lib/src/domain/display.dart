import 'package:meta/meta.dart';

import 'package:screen_capture_kit/src/domain/value_objects/display_id.dart';
import 'package:screen_capture_kit/src/domain/value_objects/frame_size.dart';

/// A display device available for capture.
///
/// Maps to [SCDisplay](https://developer.apple.com/documentation/screencapturekit/scdisplay).
@immutable
class Display {
  /// Creates a [Display] with the given properties.
  const Display({
    required this.displayId,
    required this.size,
  });

  /// The display identifier.
  final DisplayId displayId;

  /// The size of the display in pixels.
  final FrameSize size;

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
          size == other.size;

  @override
  int get hashCode => Object.hash(displayId, size);

  @override
  String toString() =>
      'Display(displayId: ${displayId.value}, width: $width, height: $height)';
}
