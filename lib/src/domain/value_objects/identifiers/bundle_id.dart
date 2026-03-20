/// Bundle identifier for a macOS application (reverse-DNS string).
///
/// Wraps the value from `SCRunningApplication.bundleIdentifier` as a distinct
/// type. The native layer may supply an empty string when no identifier exists.
///
/// Ref: [SCRunningApplication](https://developer.apple.com/documentation/screencapturekit/scrunningapplication).
extension type const BundleId(String value) {}
