import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_audio.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_frame.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/content_sharing_picker_configuration.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/stream_configuration.dart';
import 'package:screen_capture_kit/src/domain/value_objects/identifiers/filter_id.dart';

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
  final void Function(FilterId handle) updateContentFilter;

  /// Sets the content-sharing picker configuration for this stream (macOS 14+).
  /// Pass a config to restrict modes or exclude content; pass `null` for
  /// system default.
  final void Function(ContentSharingPickerConfiguration? config)
  setContentSharingPickerConfiguration;
}
