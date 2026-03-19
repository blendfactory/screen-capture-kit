import 'dart:async';
import 'dart:io' show Platform;

import 'package:screen_capture_kit/src/domain/entities/display.dart';
import 'package:screen_capture_kit/src/domain/entities/window.dart';
import 'package:screen_capture_kit/src/domain/shareable_content.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_frame.dart';
import 'package:screen_capture_kit/src/domain/value_objects/capture/captured_image.dart';
import 'package:screen_capture_kit/src/domain/value_objects/geometry/pixel_rect.dart';
import 'package:screen_capture_kit/src/presentation/capture_stream.dart';
import 'package:screen_capture_kit/src/presentation/content_filter_handle.dart';
import 'package:screen_capture_kit/src/presentation/content_sharing_picker_mode.dart';

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

ContentFilterHandle createWindowFilterImpl(Window window) {
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

ContentFilterHandle createDisplayFilterImpl(
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

void releaseFilterImpl(ContentFilterHandle handle) {
  if (!Platform.isMacOS) {
    return;
  }
  // No-op in stub; native impl would release the filter.
}

ContentFilterHandle? presentContentSharingPickerImpl({
  List<ContentSharingPickerMode>? allowedModes,
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

CapturedImage captureScreenshotImpl(
  ContentFilterHandle filterHandle, {
  int width = 0,
  int height = 0,
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
  ContentFilterHandle filterHandle, {
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
  ContentFilterHandle filterHandle, {
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
