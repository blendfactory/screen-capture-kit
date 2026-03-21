import 'dart:async';
import 'dart:io' show Platform;

import 'package:screen_capture_kit/src/domain/entities/display.dart';
import 'package:screen_capture_kit/src/domain/entities/shareable_content.dart';
import 'package:screen_capture_kit/src/domain/entities/window.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_frame.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_image.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/content_sharing_picker_mode.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/frame_rate.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/queue_depth.dart';
import 'package:screen_capture_kit/src/domain/value_objects/geometry/frame_size.dart';
import 'package:screen_capture_kit/src/domain/value_objects/geometry/pixel_rect.dart';
import 'package:screen_capture_kit/src/domain/value_objects/identifiers/filter_id.dart';
import 'package:screen_capture_kit/src/presentation/capture_stream.dart';

/// Stub implementation that throws on unsupported platforms.
ShareableContent getShareableContentImpl({
  bool excludeDesktopWindows = false,
  bool onScreenWindowsOnly = true,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }
  throw UnimplementedError(
    'Native implementation not yet loaded. '
    'Ensure the native library is built.',
  );
}

FilterId createWindowFilterImpl(Window window) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }
  throw UnimplementedError(
    'Native implementation not yet loaded. '
    'Ensure the native library is built.',
  );
}

FilterId createDisplayFilterImpl(
  Display display, {
  List<Window>? excludingWindows,
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }
  throw UnimplementedError(
    'Native implementation not yet loaded. '
    'Ensure the native library is built.',
  );
}

void releaseFilterImpl(FilterId handle) {
  if (!Platform.isMacOS) {
    return;
  }
  // No-op in stub; native impl would release the filter.
}

Future<FilterId?> presentContentSharingPickerImpl({
  List<ContentSharingPickerMode>? allowedModes,
}) {
  if (!Platform.isMacOS) {
    return Future<FilterId?>.error(
      UnsupportedError(
        'screen_capture_kit only supports macOS. '
        'Current platform: ${Platform.operatingSystem}',
      ),
    );
  }
  return Future<FilterId?>.error(
    UnimplementedError(
      'Native implementation not yet loaded. '
      'Ensure the native library is built.',
    ),
  );
}

CapturedImage captureScreenshotImpl(
  FilterId filterHandle, {
  FrameSize frameSize = const FrameSize.zero(),
}) {
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }
  throw UnimplementedError(
    'Native implementation not yet loaded. '
    'Ensure the native library is built.',
  );
}

Stream<CapturedFrame> startCaptureStreamImpl(
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
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }
  throw UnimplementedError(
    'Native implementation not yet loaded. '
    'Ensure the native library is built.',
  );
}

CaptureStream startCaptureStreamWithUpdaterImpl(
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
  if (!Platform.isMacOS) {
    throw UnsupportedError(
      'screen_capture_kit only supports macOS. '
      'Current platform: ${Platform.operatingSystem}',
    );
  }
  throw UnimplementedError(
    'Native implementation not yet loaded. '
    'Ensure the native library is built.',
  );
}
