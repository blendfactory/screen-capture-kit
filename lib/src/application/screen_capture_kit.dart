import 'dart:isolate';

import 'package:screen_capture_kit/src/capture_stream.dart';
import 'package:screen_capture_kit/src/captured_frame.dart';
import 'package:screen_capture_kit/src/captured_image.dart';
import 'package:screen_capture_kit/src/content_filter_handle.dart';
import 'package:screen_capture_kit/src/content_sharing_picker_mode.dart';
import 'package:screen_capture_kit/src/display.dart';
import 'package:screen_capture_kit/src/screen_capture_kit_stub.dart'
    if (dart.library.io) 'package:screen_capture_kit/src/screen_capture_kit_macos.dart';
import 'package:screen_capture_kit/src/shareable_content.dart';
import 'package:screen_capture_kit/src/window.dart';

/// Application-layer port for ScreenCaptureKit operations.
abstract class ScreenCaptureKitPort {
  Future<ShareableContent> getShareableContent({
    bool excludeDesktopWindows,
    bool onScreenWindowsOnly,
  });

  Future<ContentFilterHandle> createWindowFilter(Window window);

  Future<ContentFilterHandle> createDisplayFilter(
    Display display, {
    List<Window>? excludingWindows,
  });

  void releaseFilter(ContentFilterHandle handle);

  Future<ContentFilterHandle?> presentContentSharingPicker({
    List<ContentSharingPickerMode>? allowedModes,
  });

  Future<CapturedImage> captureScreenshot(
    ContentFilterHandle filterHandle, {
    int width,
    int height,
  });

  Stream<CapturedFrame> startCaptureStream(
    ContentFilterHandle filterHandle, {
    int width,
    int height,
    int frameRate,
    ({double x, double y, double width, double height})? sourceRect,
    bool showsCursor,
    int queueDepth,
    bool capturesAudio,
    bool excludesCurrentProcessAudio,
    bool captureMicrophone,
    int? pixelFormat,
    String? colorSpaceName,
  });

  CaptureStream startCaptureStreamWithUpdater(
    ContentFilterHandle filterHandle, {
    int width,
    int height,
    int frameRate,
    ({double x, double y, double width, double height})? sourceRect,
    bool showsCursor,
    int queueDepth,
    bool capturesAudio,
    bool excludesCurrentProcessAudio,
    bool captureMicrophone,
    int? pixelFormat,
    String? colorSpaceName,
  });
}

/// Default implementation of [ScreenCaptureKitPort] that delegates to the
/// platform-specific implementations in `screen_capture_kit_stub` /
/// `screen_capture_kit_macos`.
class ScreenCaptureKitImpl implements ScreenCaptureKitPort {
  @override
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

  @override
  Future<ContentFilterHandle> createWindowFilter(Window window) {
    return Isolate.run(() => createWindowFilterImpl(window));
  }

  @override
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

  @override
  void releaseFilter(ContentFilterHandle handle) {
    releaseFilterImpl(handle);
  }

  @override
  Future<ContentFilterHandle?> presentContentSharingPicker({
    List<ContentSharingPickerMode>? allowedModes,
  }) {
    return Isolate.run(
      () => presentContentSharingPickerImpl(allowedModes: allowedModes),
    );
  }

  @override
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

  @override
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
    int? pixelFormat,
    String? colorSpaceName,
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
      pixelFormat: pixelFormat,
      colorSpaceName: colorSpaceName,
    );
  }

  @override
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
    int? pixelFormat,
    String? colorSpaceName,
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
      pixelFormat: pixelFormat,
      colorSpaceName: colorSpaceName,
    );
  }
}


