import 'dart:async';
import 'dart:io' show Platform;

import 'package:screen_capture_kit/src/captured_frame.dart';
import 'package:screen_capture_kit/src/captured_image.dart';
import 'package:screen_capture_kit/src/content_filter_handle.dart';
import 'package:screen_capture_kit/src/display.dart';
import 'package:screen_capture_kit/src/shareable_content.dart';
import 'package:screen_capture_kit/src/window.dart';

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

ContentFilterHandle createDisplayFilterImpl(Display display) {
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
  ({double x, double y, double width, double height})? sourceRect,
  bool showsCursor = true,
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
