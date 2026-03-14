import 'package:screen_capture_kit/src/captured_frame.dart';

/// A capture stream that supports updating configuration at runtime.
///
/// Create via the library's startCaptureStreamWithUpdater method. Listen to
/// [stream] for frames; call [updateConfiguration] to change resolution,
/// frame rate, or other options without stopping the stream.
///
/// Ref: https://developer.apple.com/documentation/screencapturekit/scstream/3944914-updateconfiguration
class CaptureStream {
  CaptureStream({
    required this.stream,
    required this.updateConfiguration,
  });

  /// The stream of captured frames. Cancel the subscription to stop capture.
  final Stream<CapturedFrame> stream;

  /// Updates the stream configuration (e.g. width, height, frame rate).
  /// May block briefly; throws on error.
  final void Function(StreamConfiguration options) updateConfiguration;
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
  });

  final int width;
  final int height;
  final int frameRate;
  final ({double x, double y, double width, double height})? sourceRect;
  final bool showsCursor;
  final int queueDepth;
}
