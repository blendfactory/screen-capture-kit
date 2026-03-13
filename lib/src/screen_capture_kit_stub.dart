import 'dart:io' show Platform;

import 'package:screen_capture_kit/src/shareable_content.dart';

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
