/// Kind of event forwarded from Apple's [SCStreamDelegate](https://developer.apple.com/documentation/screencapturekit/scstreamdelegate).
enum CaptureStreamDelegateEventKind {
  /// Maps to `stream(_:didStopWithError:)`.
  didStopWithError,

  /// Maps to `outputVideoEffectDidStart(for:)` (macOS 14+).
  outputVideoEffectDidStart,

  /// Maps to `outputVideoEffectDidStop(for:)` (macOS 14+).
  outputVideoEffectDidStop,
}

/// A lifecycle event from the native capture stream delegate.
///
/// For [CaptureStreamDelegateEventKind.didStopWithError], [errorDomain],
/// [errorCode], and [errorDescription] mirror the `NSError` when present; all
/// are null when the framework reported a stop without an error object.
class CaptureStreamDelegateEvent {
  CaptureStreamDelegateEvent.didStopWithError({
    this.errorDomain,
    this.errorCode,
    this.errorDescription,
  }) : kind = CaptureStreamDelegateEventKind.didStopWithError;

  const CaptureStreamDelegateEvent.outputVideoEffectDidStart()
    : kind = CaptureStreamDelegateEventKind.outputVideoEffectDidStart,
      errorDomain = null,
      errorCode = null,
      errorDescription = null;

  const CaptureStreamDelegateEvent.outputVideoEffectDidStop()
    : kind = CaptureStreamDelegateEventKind.outputVideoEffectDidStop,
      errorDomain = null,
      errorCode = null,
      errorDescription = null;

  /// Which delegate callback produced this event.
  final CaptureStreamDelegateEventKind kind;

  /// Set for [CaptureStreamDelegateEventKind.didStopWithError] when an error
  /// was provided; otherwise null.
  final String? errorDomain;

  /// Set for [CaptureStreamDelegateEventKind.didStopWithError] when an error
  /// was provided; otherwise null.
  final int? errorCode;

  /// Set for [CaptureStreamDelegateEventKind.didStopWithError] when an error
  /// was provided; otherwise null.
  final String? errorDescription;
}
