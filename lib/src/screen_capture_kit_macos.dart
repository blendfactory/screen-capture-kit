import 'dart:io' show Platform;

import 'shareable_content.dart';

/// macOS implementation of shareable content retrieval.
///
/// Will call native ScreenCaptureKit API when the native library is built.
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
  // TODO: Load native library and call SCShareableContent.getExcludingDesktopWindows
  throw UnimplementedError(
    'Native ScreenCaptureKit bridge not yet implemented. '
    'See screen-capture-kit-native-bridge skill for implementation.',
  );
}
