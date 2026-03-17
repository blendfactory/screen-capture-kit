import 'package:screen_capture_kit/src/display.dart';
import 'package:screen_capture_kit/src/running_application.dart';
import 'package:screen_capture_kit/src/window.dart';

/// Shareable content (displays, apps, windows) available for capture.
///
/// Maps to [SCShareableContent](https://developer.apple.com/documentation/screencapturekit/scshareablecontent).
class ShareableContent {
  /// Creates a [ShareableContent] with the given lists.
  const ShareableContent({
    required this.displays,
    required this.applications,
    required this.windows,
  });

  /// The displays available for capture.
  final List<Display> displays;

  /// The running applications available for capture.
  final List<RunningApplication> applications;

  /// The windows available for capture.
  final List<Window> windows;

  @override
  String toString() =>
      'ShareableContent(displays: ${displays.length}, '
      'applications: ${applications.length}, windows: ${windows.length})';
}
