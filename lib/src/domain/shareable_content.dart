import 'package:meta/meta.dart';
import 'package:screen_capture_kit/src/domain/display.dart';
import 'package:screen_capture_kit/src/domain/running_application.dart';
import 'package:screen_capture_kit/src/domain/window.dart';

/// Shareable content (displays, apps, windows) available for capture.
///
/// Maps to [SCShareableContent](https://developer.apple.com/documentation/screencapturekit/scshareablecontent).
@immutable
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
