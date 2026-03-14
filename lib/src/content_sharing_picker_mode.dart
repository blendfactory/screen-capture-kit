/// Selection modes for the system content-sharing picker (macOS 14+).
///
/// Maps to [SCContentSharingPickerMode](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpickermode).
enum ContentSharingPickerMode {
  /// Single display selection.
  singleDisplay,

  /// Single window selection.
  singleWindow,

  /// Single application selection.
  singleApplication,

  /// Multiple windows selection.
  multipleWindows,

  /// Multiple applications selection.
  multipleApplications,
}
