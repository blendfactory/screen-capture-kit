import 'package:screen_capture_kit/screen_capture_kit.dart' show CaptureStream;
import 'package:screen_capture_kit/src/domain/value_objects/geometry/pixel_rect.dart';
import 'package:screen_capture_kit/src/presentation/capture_stream.dart' show CaptureStream;

/// Options for stream configuration.
///
/// Used with updateConfiguration for changing stream config at runtime.
class StreamConfiguration {
  const StreamConfiguration({
    this.width = 0,
    this.height = 0,
    this.frameRate = 60,
    this.sourceRect,
    this.showsCursor = true,
    this.queueDepth = 5,
    this.capturesAudio = false,
    this.excludesCurrentProcessAudio = false,
    this.captureMicrophone = false,
    this.pixelFormat,
    this.colorSpaceName,
  });

  final int width;
  final int height;
  final int frameRate;
  final PixelRect? sourceRect;
  final bool showsCursor;
  final int queueDepth;

  /// When true, system audio is captured and available on
  /// [CaptureStream.audioStream].
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
