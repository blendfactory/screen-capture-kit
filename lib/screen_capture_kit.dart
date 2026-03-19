/// Native Dart bindings for macOS ScreenCaptureKit.
///
/// Provides high-performance access to Apple's ScreenCaptureKit API for
/// screen, window, and display capture on macOS 12.3+.
library;

import 'package:screen_capture_kit/src/application/screen_capture_kit.dart'
    as app;
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
import 'package:screen_capture_kit/src/presentation/capture_stream.dart';

export 'src/domain/entities/display.dart';
export 'src/domain/entities/running_application.dart';
export 'src/domain/entities/shareable_content.dart';
export 'src/domain/entities/window.dart';
export 'src/domain/errors/screen_capture_kit_exception.dart';
export 'src/domain/value_objects/capture/captured_audio.dart';
export 'src/domain/value_objects/capture/captured_frame.dart';
export 'src/domain/value_objects/capture/captured_image.dart';
export 'src/domain/value_objects/capture/content_filter.dart';
export 'src/domain/value_objects/capture/content_sharing_picker_configuration.dart';
export 'src/domain/value_objects/capture/content_sharing_picker_mode.dart';
export 'src/domain/value_objects/capture/stream_configuration.dart';
export 'src/domain/value_objects/geometry/frame_size.dart';
export 'src/domain/value_objects/geometry/pixel_rect.dart';
export 'src/domain/value_objects/identifiers/display_id.dart';
export 'src/domain/value_objects/identifiers/filter_id.dart';
export 'src/domain/value_objects/identifiers/process_id.dart';
export 'src/domain/value_objects/identifiers/window_id.dart';
export 'src/presentation/capture_stream.dart';

/// Client for macOS ScreenCaptureKit API.
///
/// Use this class for dependency injection to enable mocking in tests.
///
/// Example:
/// ```dart
/// final kit = ScreenCaptureKit();
/// final content = await kit.getShareableContent();
/// ```
class ScreenCaptureKit implements app.ScreenCaptureKitPort {
  ScreenCaptureKit() : _impl = app.ScreenCaptureKitImpl();

  final app.ScreenCaptureKitPort _impl;
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
