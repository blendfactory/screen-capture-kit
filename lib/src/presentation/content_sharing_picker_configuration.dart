import 'package:screen_capture_kit/src/presentation/content_sharing_picker_mode.dart';

/// Configuration for the system content-sharing picker (macOS 14+).
///
/// Use with `CaptureStream.setContentSharingPickerConfiguration` to control
/// picker behavior for an active stream.
///
/// Ref: https://developer.apple.com/documentation/screencapturekit/sccontentsharingpickerconfiguration
class ContentSharingPickerConfiguration {
  const ContentSharingPickerConfiguration({
    this.allowedModes,
    this.allowsChangingSelectedContent,
    this.excludedBundleIds,
    this.excludedWindowIds,
  });

  /// Allowed selection modes. When null, all modes are allowed.
  final List<ContentSharingPickerMode>? allowedModes;

  /// Whether the user can change the selected content for the stream.
  final bool? allowsChangingSelectedContent;

  /// Bundle IDs to exclude from the picker.
  final List<String>? excludedBundleIds;

  /// Window IDs to exclude from the picker.
  final List<int>? excludedWindowIds;
}
