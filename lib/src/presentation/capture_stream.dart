import 'package:screen_capture_kit/src/domain/value_objects/captured_audio.dart';
import 'package:screen_capture_kit/src/domain/value_objects/captured_frame.dart';
import 'package:screen_capture_kit/src/domain/value_objects/pixel_rect.dart';
import 'package:screen_capture_kit/src/presentation/content_filter_handle.dart';
import 'package:screen_capture_kit/src/presentation/content_sharing_picker_configuration.dart';

/// A capture stream that supports updating configuration and filter at runtime.
///
/// Create via the library's startCaptureStreamWithUpdater method. Listen to
/// [stream] for frames; when audio capture was enabled, listen to [audioStream]
/// for system audio. Call [updateConfiguration], [updateContentFilter], or
/// [setContentSharingPickerConfiguration] to change without stopping.
///
/// Ref: https://developer.apple.com/documentation/screencapturekit/scstream/3944914-updateconfiguration
class CaptureStream {
  CaptureStream({
    required this.stream,
    required this.updateConfiguration,
    required this.updateContentFilter,
    required this.setContentSharingPickerConfiguration,
    this.audioStream,
    this.microphoneStream,
  });

  /// The stream of captured frames. Cancel the subscription to stop capture.
  final Stream<CapturedFrame> stream;

  /// Optional stream of captured audio buffers. Non-null when started with
  /// [StreamConfiguration.capturesAudio] set to true.
  final Stream<CapturedAudio>? audioStream;

  /// Optional stream of microphone buffers. Non-null when started with
  /// [StreamConfiguration.captureMicrophone] set to true (macOS 15+).
  final Stream<CapturedAudio>? microphoneStream;

  /// Updates the stream configuration (e.g. width, height, frame rate).
  /// May block briefly; throws on error.
  final void Function(StreamConfiguration options) updateConfiguration;

  /// Updates the content filter (e.g. switch to another display or window).
  /// May block briefly; throws on error. Release the handle when no longer
  /// needed via the library's releaseFilter.
  final void Function(ContentFilterHandle handle) updateContentFilter;

  /// Sets the content-sharing picker configuration for this stream (macOS 14+).
  /// Pass a config to restrict modes or exclude content; pass `null` for
  /// system default.
  final void Function(ContentSharingPickerConfiguration? config)
  setContentSharingPickerConfiguration;
}

/// Options for [CaptureStream.updateConfiguration].
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
