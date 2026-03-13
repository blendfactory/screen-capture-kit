/// Native Dart bindings for macOS ScreenCaptureKit.
///
/// Provides high-performance access to Apple's ScreenCaptureKit API for
/// screen, window, and display capture on macOS 12.3+.
library;

import 'dart:isolate';

import 'package:screen_capture_kit/src/content_filter_handle.dart';
import 'package:screen_capture_kit/src/screen_capture_kit_stub.dart'
    if (dart.library.io) 'package:screen_capture_kit/src/screen_capture_kit_macos.dart';
import 'package:screen_capture_kit/src/shareable_content.dart';
import 'package:screen_capture_kit/src/window.dart';

export 'src/content_filter.dart';
export 'src/content_filter_handle.dart';
export 'src/display.dart';
export 'src/running_application.dart';
export 'src/screen_capture_kit_exception.dart';
export 'src/shareable_content.dart';
export 'src/window.dart';

/// Client for macOS ScreenCaptureKit API.
///
/// Use this class for dependency injection to enable mocking in tests.
///
/// Example:
/// ```dart
/// final kit = ScreenCaptureKit();
/// final content = await kit.getShareableContent();
/// ```
class ScreenCaptureKit {
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
  }) {
    return Isolate.run(
      () => getShareableContentImpl(
        excludeDesktopWindows: excludeDesktopWindows,
        onScreenWindowsOnly: onScreenWindowsOnly,
      ),
    );
  }

  /// Creates a native content filter for capturing the given window.
  ///
  /// Returns a [ContentFilterHandle] that must be released with [releaseFilter]
  /// when no longer needed. The handle will be used when implementing capture
  /// streams.
  ///
  /// Requires Screen Recording permission.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentfilter/3944912-init
  Future<ContentFilterHandle> createWindowFilter(Window window) {
    return Isolate.run(() => createWindowFilterImpl(window));
  }

  /// Releases a content filter created by [createWindowFilter].
  void releaseFilter(ContentFilterHandle handle) {
    releaseFilterImpl(handle);
  }
}
