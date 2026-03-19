import 'package:screen_capture_kit/screen_capture_kit.dart' show FrameSize;
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
    this.pixelFormat,
    this.colorSpaceName,
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

  /// Optional CVPixelFormatType (e.g. 0x42475241 for BGRA). 0 or null =
  /// default.
  final int? pixelFormat;

  /// Optional color space name (e.g. kCGColorSpaceSRGB). null or empty =
  /// default.
  final String? colorSpaceName;
}
