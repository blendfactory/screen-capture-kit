import 'package:meta/meta.dart';
import 'package:screen_capture_kit/src/running_application.dart';

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
  final int windowId;

  /// The frame of the window (x, y, width, height).
  final ({double x, double y, double width, double height}) frame;

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
      'Window(windowId: $windowId, frame: $frame, title: $title)';
}
