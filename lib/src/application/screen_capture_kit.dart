import 'dart:isolate';

import 'package:screen_capture_kit/src/domain/entities/display.dart';
import 'package:screen_capture_kit/src/domain/entities/shareable_content.dart';
import 'package:screen_capture_kit/src/domain/entities/window.dart';
import 'package:screen_capture_kit/src/domain/errors/screen_capture_kit_exception.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_audio.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_frame.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_image.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/content_sharing_picker_mode.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/frame_rate.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/queue_depth.dart';
import 'package:screen_capture_kit/src/domain/value_objects/geometry/frame_size.dart'
    show FrameSize;
import 'package:screen_capture_kit/src/domain/value_objects/geometry/pixel_rect.dart';
import 'package:screen_capture_kit/src/domain/value_objects/identifiers/filter_id.dart';
import 'package:screen_capture_kit/src/infrastructure/screen_capture_kit_stub.dart'
    if (dart.library.io) 'package:screen_capture_kit/src/infrastructure/screen_capture_kit_macos.dart';
import 'package:screen_capture_kit/src/presentation/capture_stream.dart';

/// Client for macOS ScreenCaptureKit API.
///
/// Use this class for dependency injection; tests can substitute a fake with
/// `implements ScreenCaptureKit` or a mocking package.
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
  /// Returns a [FilterId] that must be released with [releaseFilter]
  /// when no longer needed. The handle will be used when implementing capture
  /// streams.
  ///
  /// Requires Screen Recording permission.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentfilter/3944912-init
  Future<FilterId> createWindowFilter(Window window) {
    return Isolate.run(() => createWindowFilterImpl(window));
  }

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

  /// Releases a content filter created by [createWindowFilter] or
  /// [createDisplayFilter].
  void releaseFilter(FilterId handle) {
    releaseFilterImpl(handle);
  }

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
  ///
  /// **Threading:** Native runs the picker session on the **calling isolate’s
  /// thread** (see `picker_start` in `native/picker.m`).
  Future<FilterId?> presentContentSharingPicker({
    List<ContentSharingPickerMode>? allowedModes,
  }) {
    return presentContentSharingPickerImpl(allowedModes: allowedModes);
  }

  /// Captures a single screenshot using the given content filter.
  ///
  /// Returns PNG-encoded image data. Requires macOS 14.0 or newer.
  /// On older macOS, throws [ScreenCaptureKitException].
  ///
  /// [frameSize] optionally sets output dimensions; use [FrameSize.zero] to
  /// let the native layer choose.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager/captureimage(contentfilter:configuration:completionhandler:)
  Future<CapturedImage> captureScreenshot(
    FilterId filterHandle, {
    FrameSize frameSize = const FrameSize.zero(),
  }) {
    return Isolate.run(
      () => captureScreenshotImpl(
        filterHandle,
        frameSize: frameSize,
      ),
    );
  }

  /// Starts a capture stream yielding [CapturedFrame]s (BGRA pixel data).
  ///
  /// [frameRate] sets the target fps (1–120).
  /// [sourceRect] optionally crops to a region (x, y, width, height) in screen
  /// points. Use with display filter for region capture.
  /// [showsCursor] includes the system cursor in capture when true (default).
  /// [queueDepth] sets the frame queue depth (1–8).
  /// [capturesAudio] when true, system audio is captured (use with
  /// [startCaptureStreamWithUpdater] to get [CaptureStream.audioStream]).
  /// [excludesCurrentProcessAudio] excludes this app's audio from capture.
  /// [captureMicrophone] includes microphone in the audio capture.
  /// [pixelFormat] optional `CVPixelFormatType` as `int`; null = default.
  /// See [Pixel format identifiers](https://developer.apple.com/documentation/corevideo/pixel-format-identifiers)
  /// and [CVPixelFormatType](https://developer.apple.com/documentation/corevideo/cvpixelformattype).
  /// [colorSpaceName] optional color space name (e.g. kCGColorSpaceSRGB);
  /// null = default.
  /// Cancel the stream subscription to stop capture.
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scstream
  Stream<CapturedFrame> startCaptureStream(
    FilterId filterHandle, {
    FrameSize frameSize = const FrameSize.zero(),
    FrameRate frameRate = const FrameRate.fps60(),
    PixelRect? sourceRect,
    bool showsCursor = true,
    QueueDepth queueDepth = const QueueDepth.depth5(),
    bool capturesAudio = false,
    bool excludesCurrentProcessAudio = false,
    bool captureMicrophone = false,
    int? pixelFormat,
    String? colorSpaceName,
  }) {
    return startCaptureStreamImpl(
      filterHandle,
      frameSize: frameSize,
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

  /// Starts a capture stream and returns a [CaptureStream] that supports
  /// [CaptureStream.updateConfiguration] for changing config at runtime.
  ///
  /// Use [CaptureStream.stream] for frames. When [capturesAudio] is true,
  /// [CaptureStream.audioStream] yields [CapturedAudio] buffers. Cancel the
  /// video subscription to stop capture.
  ///
  /// [pixelFormat] and [colorSpaceName] match [startCaptureStream].
  ///
  /// Ref: https://developer.apple.com/documentation/screencapturekit/scstream/3944914-updateconfiguration
  CaptureStream startCaptureStreamWithUpdater(
    FilterId filterHandle, {
    FrameSize frameSize = const FrameSize.zero(),
    FrameRate frameRate = const FrameRate.fps60(),
    PixelRect? sourceRect,
    bool showsCursor = true,
    QueueDepth queueDepth = const QueueDepth.depth5(),
    bool capturesAudio = false,
    bool excludesCurrentProcessAudio = false,
    bool captureMicrophone = false,
    int? pixelFormat,
    String? colorSpaceName,
  }) {
    return startCaptureStreamWithUpdaterImpl(
      filterHandle,
      frameSize: frameSize,
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
