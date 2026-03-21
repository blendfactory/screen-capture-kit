/// Output resolution / quality for screenshot and live stream capture.
///
/// Maps to [SCCaptureResolutionType](https://developer.apple.com/documentation/screencapturekit/sccaptureresolutiontype)
/// on `SCStreamConfiguration` for
/// [`captureImage(contentFilter:configuration:completionHandler:)`](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager/captureimage(contentfilter:configuration:completionhandler:))
/// and for live [`SCStream`](https://developer.apple.com/documentation/screencapturekit/scstream)
/// configuration (macOS 14+).
enum CaptureResolution {
  /// System chooses resolution based on conditions (e.g. network).
  automatic,

  /// Highest quality capture for the configured output size.
  best,

  /// Nominal resolution.
  nominal,
}
