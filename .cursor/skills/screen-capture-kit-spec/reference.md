# ScreenCaptureKit API Reference

Full specification for Apple's ScreenCaptureKit framework. Use when implementing Dart bindings.

Ref: https://developer.apple.com/documentation/screencapturekit

## Shareable content

### SCShareableContent

Represents displays, apps, and windows available for capture.

| Property | Type | Description |
|----------|------|-------------|
| `displays` | [SCDisplay] | Displays available for capture |
| `windows` | [SCWindow] | Windows available for capture |
| `applications` | [SCRunningApplication] | Apps available for capture |

**Methods:**
- `getWithCompletionHandler(_:)` — Retrieve shareable content
- `getExcludingDesktopWindows(_:onScreenWindowsOnly:completionHandler:)` — Retrieve with filters
- `getExcludingDesktopWindows(_:onScreenWindowsOnlyAbove:completionHandler:)` — Content in front of window
- `getExcludingDesktopWindows(_:onScreenWindowsOnlyBelow:completionHandler:)` — Content behind window
- `info(for:)` — Sharable content info for a filter

### SCDisplay

Represents a display device. Properties: `displayID`, `width`, `height`, etc.

### SCRunningApplication

Represents a running app. Properties: `bundleIdentifier`, `applicationName`, etc.

### SCWindow

Represents an onscreen window. Properties: `windowID`, `frame`, `owningApplication`, etc.

---

## Content filter

### SCContentFilter

Filters which content a stream captures.

**Initializers:**
- `init(desktopIndependentWindow:)` — Single window
- `init(display:including:)` — Specific windows from display
- `init(display:excludingWindows:)` — Display excluding windows
- `init(display:including:exceptingWindows:)` — Display, only windows of specified apps
- `init(display:excludingApplications:exceptingWindows:)` — Display excluding apps

**Properties:**
- `contentRect` — Size and location (screen points)
- `pointPixelScale` — Scale factor
- `streamType` — SCStreamType
- `style` — SCShareableContentStyle

---

## Stream configuration

### SCStreamConfiguration

Output configuration for a stream.

**Dimensions:** `width`, `height`, `scalesToFit`, `sourceRect`, `destinationRect`, `preservesAspectRatio`

**Colors:** `pixelFormat`, `colorMatrix`, `colorSpaceName`, `backgroundColor`

**Captured elements:** `showsCursor`, `shouldBeOpaque`, `capturesShadowsOnly`, `ignoreShadowsDisplay`, `ignoreShadowsSingleWindow`, `ignoreGlobalClipDisplay`, `ignoreGlobalClipSingleWindow`

**Frames:** `queueDepth` (default 3, max 8), `minimumFrameInterval`, `captureResolution`

**Audio:** `capturesAudio`, `sampleRate`, `channelCount`, `excludesCurrentProcessAudio`, `captureMicrophone`

**Other:** `streamName`, `presenterOverlayPrivacyAlertSetting`

---

## Stream

### SCStream

Represents a capture stream.

- `init(filter:configuration:delegate:)`
- `addStreamOutput(_:type:sampleHandlerQueue:)` — Add output for video/audio/microphone
- `startCapture()`
- `stopCapture()`
- `updateConfiguration(_:)` — Update config without restart
- `updateContentFilter(_:)` — Update filter without restart

### SCStreamDelegate

Stream lifecycle events.

In this package: a **subset** is available when starting a stream with `emitDelegateEvents: true` — see `CaptureStream.delegateEvents` and `CaptureStreamDelegateEvent` in the Dart API (not the full Objective-C protocol).

### SCStreamOutput

Receives `CMSampleBuffer` via `stream(_:didOutputSampleBuffer:of:)`.

### SCStreamOutputType

`.screen`, `.audio`, `.microphone`

### SCStreamFrameInfo

Metadata keys for frame attachments.

### SCFrameStatus

`.complete`, etc.

---

## Screenshot

### SCScreenshotManager

Captures single frames.

- `captureImage(contentFilter:configuration:completionHandler:)`

### SCScreenshotConfiguration

Output width, height, image quality.

### SCScreenshotOutput

Contains captured images.

---

## System picker

### SCContentSharingPicker

System UI for stream selection.

### SCContentSharingPickerConfiguration

Picker configuration.

### SCContentSharingPickerMode

Selection modes.

### SCContentSharingPickerObserver

Observer protocol for picker events.

---

## Errors

### SCStreamError

Error codes for user cancellation and stream errors.

### SCStreamErrorDomain

Error domain string.
