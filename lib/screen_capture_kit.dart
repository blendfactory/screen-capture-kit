/// Native Dart bindings for macOS ScreenCaptureKit.
///
/// Provides high-performance access to Apple's ScreenCaptureKit API for
/// screen, window, and display capture on macOS 12.3+.
library;

import 'dart:isolate';

import 'package:screen_capture_kit/src/captured_frame.dart';
import 'package:screen_capture_kit/src/captured_image.dart';
import 'package:screen_capture_kit/src/content_filter_handle.dart';
import 'package:screen_capture_kit/src/screen_capture_kit_exception.dart';
import 'package:screen_capture_kit/src/screen_capture_kit_stub.dart'
    if (dart.library.io) 'package:screen_capture_kit/src/screen_capture_kit_macos.dart';
import 'package:screen_capture_kit/src/shareable_content.dart';
import 'package:screen_capture_kit/src/display.dart';
import 'package:screen_capture_kit/src/window.dart';

export 'src/captured_frame.dart';
export 'src/captured_image.dart';
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

  /// Creates a native content filter for capturing the entire display.
  ///
  /// Returns a [ContentFilterHandle] that must be released with [releaseFilter]
  /// when no longer needed.
  ///
  /// Requires Screen Recording permission.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentfilter/3944911-init
  Future<ContentFilterHandle> createDisplayFilter(Display display) {
    return Isolate.run(() => createDisplayFilterImpl(display));
  }

  /// Releases a content filter created by [createWindowFilter] or
  /// [createDisplayFilter].
  void releaseFilter(ContentFilterHandle handle) {
    releaseFilterImpl(handle);
  }

  /// Captures a single screenshot using the given content filter.
  ///
  /// Returns PNG-encoded image data. Requires macOS 14.0 or newer.
  /// On older macOS, throws [ScreenCaptureKitException].
  ///
  /// [width] and [height] optionally specify output dimensions; 0 uses default.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager/captureimage(contentfilter:configuration:completionhandler:)
  Future<CapturedImage> captureScreenshot(
    ContentFilterHandle filterHandle, {
    int width = 0,
    int height = 0,
  }) {
    return Isolate.run(
      () => captureScreenshotImpl(
        filterHandle,
        width: width,
        height: height,
      ),
    );
  }

  /// Starts a capture stream yielding [CapturedFrame]s (BGRA pixel data).
  ///
  /// Cancel the stream subscription to stop capture.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scstream
  Stream<CapturedFrame> startCaptureStream(
    ContentFilterHandle filterHandle, {
    int width = 0,
    int height = 0,
  }) {
    return startCaptureStreamImpl(
      filterHandle,
      width: width,
      height: height,
    );
  }
}
