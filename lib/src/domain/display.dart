import 'package:meta/meta.dart';

/// A display device available for capture.
///
/// Maps to [SCDisplay](https://developer.apple.com/documentation/screencapturekit/scdisplay).
@immutable
class Display {
  /// Creates a [Display] with the given properties.
  const Display({
    required this.displayId,
    required this.width,
    required this.height,
  });

  /// The display identifier.
  final int displayId;

  /// The width of the display in pixels.
  final int width;

  /// The height of the display in pixels.
  final int height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Display &&
          runtimeType == other.runtimeType &&
          displayId == other.displayId &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(displayId, width, height);

  @override
  String toString() =>
      'Display(displayId: $displayId, width: $width, height: $height)';
}
