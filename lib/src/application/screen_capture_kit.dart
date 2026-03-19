import 'dart:isolate';

import 'package:screen_capture_kit/src/domain/entities/display.dart';
import 'package:screen_capture_kit/src/domain/entities/shareable_content.dart';
import 'package:screen_capture_kit/src/domain/entities/window.dart';
import 'package:screen_capture_kit/src/domain/errors/screen_capture_kit_exception.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_audio.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_frame.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_image.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/content_sharing_picker_mode.dart';
import 'package:screen_capture_kit/src/domain/value_objects/geometry/pixel_rect.dart';
import 'package:screen_capture_kit/src/domain/value_objects/identifiers/filter_id.dart';
import 'package:screen_capture_kit/src/infrastructure/screen_capture_kit_stub.dart'
    if (dart.library.io)
      'package:screen_capture_kit/src/infrastructure/screen_capture_kit_macos.dart';
import 'package:screen_capture_kit/src/presentation/capture_stream.dart';

/// Application-layer port for ScreenCaptureKit operations.
abstract class ScreenCaptureKitPort {
  Future<ShareableContent> getShareableContent({
    bool excludeDesktopWindows,
    bool onScreenWindowsOnly,
  });

  Future<FilterId> createWindowFilter(Window window);

  Future<FilterId> createDisplayFilter(
    Display display, {
    List<Window>? excludingWindows,
  });

  void releaseFilter(FilterId handle);

  Future<FilterId?> presentContentSharingPicker({
    List<ContentSharingPickerMode>? allowedModes,
  });

  Future<CapturedImage> captureScreenshot(
    FilterId filterHandle, {
    int width,
    int height,
  });

  Stream<CapturedFrame> startCaptureStream(
    FilterId filterHandle, {
    int width,
    int height,
    int frameRate,
    PixelRect? sourceRect,
    bool showsCursor,
    int queueDepth,
    bool capturesAudio,
    bool excludesCurrentProcessAudio,
    bool captureMicrophone,
    int? pixelFormat,
    String? colorSpaceName,
  });

  CaptureStream startCaptureStreamWithUpdater(
    FilterId filterHandle, {
    int width,
    int height,
    int frameRate,
    PixelRect? sourceRect,
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
  Future<FilterId> createWindowFilter(Window window) {
    return Isolate.run(() => createWindowFilterImpl(window));
  }

  @override
  Future<FilterId> createDisplayFilter(
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
  void releaseFilter(FilterId handle) {
    releaseFilterImpl(handle);
  }

  @override
  Future<FilterId?> presentContentSharingPicker({
    List<ContentSharingPickerMode>? allowedModes,
  }) {
    return Isolate.run(
      () => presentContentSharingPickerImpl(allowedModes: allowedModes),
    );
  }

  @override
  Future<CapturedImage> captureScreenshot(
    FilterId filterHandle, {
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
    FilterId filterHandle, {
    int width = 0,
    int height = 0,
    int frameRate = 60,
    PixelRect? sourceRect,
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
    FilterId filterHandle, {
    int width = 0,
    int height = 0,
    int frameRate = 60,
    PixelRect? sourceRect,
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

/// Client for macOS ScreenCaptureKit API.
///
/// Use this class for dependency injection to enable mocking in tests.
///
/// Example:
/// ```dart
/// final kit = ScreenCaptureKit();
/// final content = await kit.getShareableContent();
/// ```
class ScreenCaptureKit implements ScreenCaptureKitPort {
  ScreenCaptureKit() : _impl = ScreenCaptureKitImpl();

  final ScreenCaptureKitPort _impl;

  /// Retrieves the shareable content (displays, apps, windows) available for
  /// capture.
  ///
  /// Requires Screen Recording permission. On non-macOS platforms, throws
  /// [UnsupportedError].
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scshareablecontent
  @override
  Future<ShareableContent> getShareableContent({
    bool excludeDesktopWindows = false,
    bool onScreenWindowsOnly = true,
  }) =>
      _impl.getShareableContent(
        excludeDesktopWindows: excludeDesktopWindows,
        onScreenWindowsOnly: onScreenWindowsOnly,
      );

  /// Creates a native content filter for capturing the given window.
  ///
  /// Returns a [FilterId] that must be released with [releaseFilter]
  /// when no longer needed. The handle will be used when implementing capture
  /// streams.
  ///
  /// Requires Screen Recording permission.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentfilter/3944912-init
  @override
  Future<FilterId> createWindowFilter(Window window) =>
      _impl.createWindowFilter(window);

  /// Creates a native content filter for capturing the entire display.
  ///
  /// [excludingWindows] optionally excludes specific windows from capture.
  /// Maps to `SCContentFilter(display:excludingWindows:)` when non-empty.
  ///
  /// Returns a [FilterId] that must be released with [releaseFilter]
  /// when no longer needed.
  ///
  /// Requires Screen Recording permission.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentfilter/3944911-init
  @override
  Future<FilterId> createDisplayFilter(
    Display display, {
    List<Window>? excludingWindows,
  }) =>
      _impl.createDisplayFilter(
        display,
        excludingWindows: excludingWindows,
      );

  /// Releases a content filter created by [createWindowFilter] or
  /// [createDisplayFilter].
  @override
  void releaseFilter(FilterId handle) => _impl.releaseFilter(handle);

  /// Presents the system content-sharing picker (macOS 14+).
  ///
  /// Returns a [FilterId] for the selected content when the user
  /// confirms, or `null` when the user cancels. The handle must be released
  /// with [releaseFilter] when no longer needed.
  ///
  /// [allowedModes] optionally restricts selection to specific modes (e.g.
  /// only [ContentSharingPickerMode.singleDisplay]).
  ///
  /// Requires Screen Recording permission. On macOS &lt; 14, throws
  /// [ScreenCaptureKitException].
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker
  @override
  Future<FilterId?> presentContentSharingPicker({
    List<ContentSharingPickerMode>? allowedModes,
  }) =>
      _impl.presentContentSharingPicker(allowedModes: allowedModes);

  /// Captures a single screenshot using the given content filter.
  ///
  /// Returns PNG-encoded image data. Requires macOS 14.0 or newer.
  /// On older macOS, throws [ScreenCaptureKitException].
  ///
  /// [width] and [height] optionally specify output dimensions; 0 uses default.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager/captureimage(contentfilter:configuration:completionhandler:)
  @override
  Future<CapturedImage> captureScreenshot(
    FilterId filterHandle, {
    int width = 0,
    int height = 0,
  }) =>
      _impl.captureScreenshot(
        filterHandle,
        width: width,
        height: height,
      );

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
  /// [pixelFormat] optional CVPixelFormatType (e.g. 0x42475241 for BGRA);
  /// null = default.
  /// [colorSpaceName] optional color space name (e.g. kCGColorSpaceSRGB);
  /// null = default.
  /// Cancel the stream subscription to stop capture.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scstream
  @override
  Stream<CapturedFrame> startCaptureStream(
    FilterId filterHandle, {
    int width = 0,
    int height = 0,
    int frameRate = 60,
    PixelRect? sourceRect,
    bool showsCursor = true,
    int queueDepth = 5,
    bool capturesAudio = false,
    bool excludesCurrentProcessAudio = false,
    bool captureMicrophone = false,
    int? pixelFormat,
    String? colorSpaceName,
  }) =>
      _impl.startCaptureStream(
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

  /// Starts a capture stream and returns a [CaptureStream] that supports
  /// [CaptureStream.updateConfiguration] for changing config at runtime.
  ///
  /// Use [CaptureStream.stream] for frames. When [capturesAudio] is true,
  /// [CaptureStream.audioStream] yields [CapturedAudio] buffers. Cancel the
  /// video subscription to stop capture.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scstream/3944914-updateconfiguration
  @override
  CaptureStream startCaptureStreamWithUpdater(
    FilterId filterHandle, {
    int width = 0,
    int height = 0,
    int frameRate = 60,
    PixelRect? sourceRect,
    bool showsCursor = true,
    int queueDepth = 5,
    bool capturesAudio = false,
    bool excludesCurrentProcessAudio = false,
    bool captureMicrophone = false,
    int? pixelFormat,
    String? colorSpaceName,
  }) =>
      _impl.startCaptureStreamWithUpdater(
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
