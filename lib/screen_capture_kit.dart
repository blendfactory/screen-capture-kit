/// Native Dart bindings for macOS ScreenCaptureKit.
///
/// Provides high-performance access to Apple's ScreenCaptureKit API for
/// screen, window, and display capture on macOS 12.3+.
library;

import 'dart:isolate';

import 'package:screen_capture_kit/src/capture_stream.dart';
import 'package:screen_capture_kit/src/captured_audio.dart';
import 'package:screen_capture_kit/src/captured_frame.dart';
import 'package:screen_capture_kit/src/captured_image.dart';
import 'package:screen_capture_kit/src/content_filter_handle.dart';
import 'package:screen_capture_kit/src/display.dart';
import 'package:screen_capture_kit/src/screen_capture_kit_exception.dart';
import 'package:screen_capture_kit/src/screen_capture_kit_stub.dart'
    if (dart.library.io) 'package:screen_capture_kit/src/screen_capture_kit_macos.dart';
import 'package:screen_capture_kit/src/shareable_content.dart';
import 'package:screen_capture_kit/src/window.dart';

export 'src/capture_stream.dart';
export 'src/captured_audio.dart';
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
  /// [excludingWindows] optionally excludes specific windows from capture.
  /// Maps to `SCContentFilter(display:excludingWindows:)` when non-empty.
  ///
  /// Returns a [ContentFilterHandle] that must be released with [releaseFilter]
  /// when no longer needed.
  ///
  /// Requires Screen Recording permission.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentfilter/3944911-init
  Future<ContentFilterHandle> createDisplayFilter(
    Display display, {
    List<Window>? excludingWindows,
  }) {
    return Isolate.run(
      () => createDisplayFilterImpl(
        display,
        excludingWindows: excludingWindows,
      ),
    );
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
  /// [frameRate] sets the target fps (1–120); 0 or invalid uses 60.
  /// [sourceRect] optionally crops to a region (x, y, width, height) in screen
  /// points. Use with display filter for region capture.
  /// [showsCursor] includes the system cursor in capture when true (default).
  /// [queueDepth] sets the frame queue depth (1–8); default 5.
  /// [capturesAudio] when true, system audio is captured (use with
  /// [startCaptureStreamWithUpdater] to get [CaptureStream.audioStream]).
  /// [excludesCurrentProcessAudio] excludes this app's audio from capture.
  /// [captureMicrophone] includes microphone in the audio capture.
  /// Cancel the stream subscription to stop capture.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scstream
  Stream<CapturedFrame> startCaptureStream(
    ContentFilterHandle filterHandle, {
    int width = 0,
    int height = 0,
    int frameRate = 60,
    ({double x, double y, double width, double height})? sourceRect,
    bool showsCursor = true,
    int queueDepth = 5,
    bool capturesAudio = false,
    bool excludesCurrentProcessAudio = false,
    bool captureMicrophone = false,
  }) {
    return startCaptureStreamImpl(
      filterHandle,
      width: width,
      height: height,
      frameRate: frameRate,
      sourceRect: sourceRect,
      showsCursor: showsCursor,
      queueDepth: queueDepth,
      capturesAudio: capturesAudio,
      excludesCurrentProcessAudio: excludesCurrentProcessAudio,
      captureMicrophone: captureMicrophone,
    );
  }

  /// Starts a capture stream and returns a [CaptureStream] that supports
  /// [CaptureStream.updateConfiguration] for changing config at runtime.
  ///
  /// Use [CaptureStream.stream] for frames. When [capturesAudio] is true,
  /// [CaptureStream.audioStream] yields [CapturedAudio] buffers. Cancel the
  /// video subscription to stop capture.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scstream/3944914-updateconfiguration
  CaptureStream startCaptureStreamWithUpdater(
    ContentFilterHandle filterHandle, {
    int width = 0,
    int height = 0,
    int frameRate = 60,
    ({double x, double y, double width, double height})? sourceRect,
    bool showsCursor = true,
    int queueDepth = 5,
    bool capturesAudio = false,
    bool excludesCurrentProcessAudio = false,
    bool captureMicrophone = false,
  }) {
    return startCaptureStreamWithUpdaterImpl(
      filterHandle,
      width: width,
      height: height,
      frameRate: frameRate,
      sourceRect: sourceRect,
      showsCursor: showsCursor,
      queueDepth: queueDepth,
      capturesAudio: capturesAudio,
      excludesCurrentProcessAudio: excludesCurrentProcessAudio,
      captureMicrophone: captureMicrophone,
    );
  }
}
