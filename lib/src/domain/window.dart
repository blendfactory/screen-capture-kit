import 'package:meta/meta.dart';

import 'package:screen_capture_kit/src/domain/running_application.dart';
import 'package:screen_capture_kit/src/domain/value_objects/pixel_rect.dart';
import 'package:screen_capture_kit/src/domain/value_objects/window_id.dart';

/// An onscreen window available for capture.
///
/// Maps to [SCWindow](https://developer.apple.com/documentation/screencapturekit/scwindow).
@immutable
class Window {
  /// Creates a [Window] with the given properties.
  const Window({
    required this.windowId,
    required this.frame,
    required this.owningApplication,
    this.title,
  });

  /// The window identifier.
  final WindowId windowId;

  /// The frame of the window (x, y, width, height) in screen points.
  final PixelRect frame;

  /// The application that owns this window.
  final RunningApplication owningApplication;

  /// The window title, if available.
  final String? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Window &&
          runtimeType == other.runtimeType &&
          windowId == other.windowId &&
          frame == other.frame &&
          owningApplication == other.owningApplication &&
          title == other.title;

  @override
  int get hashCode => Object.hash(windowId, frame, owningApplication, title);

  @override
  String toString() =>
      'Window(windowId: ${windowId.value}, frame: $frame, title: $title)';
}
