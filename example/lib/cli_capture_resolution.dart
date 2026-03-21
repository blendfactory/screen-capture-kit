import 'package:screen_capture_kit/screen_capture_kit.dart';

/// Parses `--quality` / `-q` values (same rules as `bin/screenshot_display.dart`).
///
/// Accepts case-insensitive: `automatic`, `auto`, `best`, `nominal`.
/// Returns `null` if [raw] is not a recognized label.
CaptureResolution? tryParseCaptureResolutionCli(String raw) {
  final s = raw.toLowerCase();
  if (s == 'automatic' || s == 'auto') {
    return CaptureResolution.automatic;
  }
  if (s == 'best') {
    return CaptureResolution.best;
  }
  if (s == 'nominal') {
    return CaptureResolution.nominal;
  }
  return null;
}
