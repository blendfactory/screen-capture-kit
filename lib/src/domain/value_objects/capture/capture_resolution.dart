/// Output resolution / quality for single-frame screenshot capture.
///
/// Maps to [SCCaptureResolutionType](https://developer.apple.com/documentation/screencapturekit/sccaptureresolutiontype)
/// on `SCStreamConfiguration` passed to
/// [`captureImage(contentFilter:configuration:completionHandler:)`](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager/captureimage(contentfilter:configuration:completionhandler:))
/// (macOS 14+).
enum CaptureResolution {
  /// System chooses resolution based on conditions (e.g. network).
  automatic,

  /// Highest quality capture for the configured output size.
  best,

  /// Nominal resolution.
  nominal,
}
