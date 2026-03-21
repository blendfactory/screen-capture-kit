/// @docImport 'package:screen_capture_kit/src/application/screen_capture_kit.dart';
library;

import 'package:screen_capture_kit/src/domain/value_objects/capture/capture_resolution.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/frame_rate.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/queue_depth.dart';
import 'package:screen_capture_kit/src/domain/value_objects/geometry/frame_size.dart';
import 'package:screen_capture_kit/src/domain/value_objects/geometry/pixel_rect.dart';

/// Options for stream configuration.
///
/// Used with `CaptureStream.updateConfiguration` for changing stream config at
/// runtime.
class StreamConfiguration {
  const StreamConfiguration({
    this.frameSize = const FrameSize.zero(),
    this.frameRate = const FrameRate.fps60(),
    this.sourceRect,
    this.showsCursor = true,
    this.queueDepth = const QueueDepth.depth5(),
    this.capturesAudio = false,
    this.excludesCurrentProcessAudio = false,
    this.captureMicrophone = false,
    this.scalesToFit,
    this.destinationRect,
    this.preservesAspectRatio,
    this.pixelFormat,
    this.colorSpaceName,
    this.captureResolution = CaptureResolution.automatic,
  });

  /// Capture output frame dimensions.
  /// [FrameSize.zero] leaves sizing to the native layer (0×0 in the
  /// Objective-C bridge).
  final FrameSize frameSize;

  /// Target capture frame rate.
  final FrameRate frameRate;
  final PixelRect? sourceRect;
  final bool showsCursor;

  /// Frame queue depth.
  final QueueDepth queueDepth;

  /// When true, system audio is captured and available on
  /// `CaptureStream.audioStream`.
  final bool capturesAudio;

  /// When true, this application's audio is excluded from capture.
  final bool excludesCurrentProcessAudio;

  /// When true, microphone input is included in the audio capture.
  final bool captureMicrophone;

  /// When set, controls whether the output is scaled to fit the provided
  /// width and height.
  ///
  /// Maps to `SCStreamConfiguration.scalesToFit`.
  ///
  /// When `null`, the native defaults remain unchanged.
  final bool? scalesToFit;

  /// When set, specifies the output subset in the pixel coordinate system.
  ///
  /// Maps to `SCStreamConfiguration.destinationRect`.
  ///
  /// Note: this is in the *pixel* coordinate space (not points).
  /// When `null`, the native defaults remain unchanged.
  final PixelRect? destinationRect;

  /// When set, controls whether the stream preserves the aspect ratio of the
  /// source pixel data.
  ///
  /// Maps to `SCStreamConfiguration.preservesAspectRatio`.
  ///
  /// When `null`, the native defaults remain unchanged.
  final bool? preservesAspectRatio;

  /// Optional Core Video pixel format (`CVPixelFormatType` as `int`). `null`
  /// or `0` = default. Full list of `kCVPixelFormatType_*` values:
  /// [Pixel format identifiers](https://developer.apple.com/documentation/corevideo/pixel-format-identifiers);
  /// type: [CVPixelFormatType](https://developer.apple.com/documentation/corevideo/cvpixelformattype).
  final int? pixelFormat;

  /// Optional color space name (e.g. kCGColorSpaceSRGB). null or empty =
  /// default.
  final String? colorSpaceName;

  /// Output resolution / quality tier for the live stream.
  ///
  /// Maps to [`SCStreamConfiguration.captureResolution`](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/captureresolution)
  /// (macOS 14+). Same enum as [ScreenCaptureKit.captureScreenshot].
  final CaptureResolution captureResolution;
}
