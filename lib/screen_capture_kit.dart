/// Native Dart bindings for macOS ScreenCaptureKit.
///
/// Provides high-performance access to Apple's ScreenCaptureKit API for
/// screen, window, and display capture on macOS 12.3+.
library screen_capture_kit;

import 'src/shareable_content.dart';
import 'src/screen_capture_kit_stub.dart'
    if (dart.library.io) 'src/screen_capture_kit_macos.dart';

export 'src/display.dart';
export 'src/running_application.dart';
export 'src/shareable_content.dart';
export 'src/window.dart';

/// Retrieves the shareable content (displays, apps, windows) available for
/// capture.
///
/// Requires Screen Recording permission. On non-macOS platforms, throws
/// [UnsupportedError].
///
/// Ref: https://developer.apple.com/documentation/screencapturekit/scshareablecontent
Future<ShareableContent> getShareableContent({
  bool excludeDesktopWindows = false,
  bool onScreenWindowsOnly = true,
}) async {
  return Future.value(getShareableContentImpl(
    excludeDesktopWindows: excludeDesktopWindows,
    onScreenWindowsOnly: onScreenWindowsOnly,
  ));
}
