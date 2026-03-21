---
name: screen-capture-kit-api-coverage
description: >-
  Tracks ScreenCaptureKit API coverage in the screen-capture-kit package. Use when
  planning features, identifying implementation gaps, or updating the roadmap.
---

# ScreenCaptureKit API Coverage

Checklist for tracking which ScreenCaptureKit APIs are implemented in the Dart package.

## When to use

- Before adding a new feature (check what's missing)
- When updating README [Roadmap](../../../README.md#roadmap) or Features
- During release planning
- When reviewing PRs for completeness

## Coverage checklist

Update status as implementation progresses. Use: ✅ Done | 🚧 In progress | ❌ Not started

### Shareable content

| API | Status | Notes |
|-----|--------|-------|
| SCShareableContent.getExcludingDesktopWindows | ✅ | Dart API + Objective-C bridge + FFI |
| SCShareableContent.displays | ✅ | Dart model `Display` |
| SCShareableContent.windows | ✅ | Dart model `Window` |
| SCShareableContent.applications | ✅ | Dart model `RunningApplication` |
| SCDisplay | ✅ | `Display` class |
| SCRunningApplication | ✅ | `RunningApplication` class |
| SCWindow | ✅ | `Window` class |

### Content filter

| API | Status | Notes |
|-----|--------|-------|
| SCContentFilter(desktopIndependentWindow:) | ✅ | Dart API + Objective-C bridge, createWindowFilter |
| SCContentFilter(display:excludingApplications:exceptingWindows:) | ✅ | createDisplayFilter (empty exclusions for full display) |
| SCContentFilter(display:excludingWindows:) | ✅ | createDisplayFilter(display, excludingWindows: …) + native bridge |
| SCContentFilter.contentRect | ✅ | via SCStreamConfiguration.sourceRect |

### Stream

| API | Status | Notes |
|-----|--------|-------|
| SCStream init | ✅ | stream.m, startCaptureStream; display stable |
| SCStream.addStreamOutput (screen) | ✅ | custom queue, BGRA frames |
| SCStream.addStreamOutput (audio) | ✅ | Dart API + native handler, PCM via stream_get_next_audio; macOS 13+ |
| SCStream.addStreamOutput (microphone) | ✅ | Dart API + native StreamMicrophoneHandler, stream_get_next_microphone; macOS 15+, CaptureStream.microphoneStream |
| SCStream.startCapture | ✅ | |
| SCStream.stopCapture | ✅ | |
| SCStream.updateConfiguration | ✅ | startCaptureStreamWithUpdater + CaptureStream.updateConfiguration |
| SCStream.updateContentFilter | ✅ | CaptureStream.updateContentFilter(FilterId) |

### Stream configuration

| Property | Status | Notes |
|----------|--------|-------|
| width, height | ✅ | via startCaptureStream |
| sourceRect | ✅ | region capture via startCaptureStream |
| minimumFrameInterval | ✅ | via startCaptureStream frameRate |
| queueDepth | ✅ | optional in startCaptureStream (1–8, default 5) |
| showsCursor | ✅ | via startCaptureStream |
| capturesAudio | ✅ | StreamConfiguration + native config; macOS 13+ |
| excludesCurrentProcessAudio | ✅ | StreamConfiguration + native config; macOS 13+ |
| captureMicrophone | ✅ | StreamConfiguration + native config; macOS 15+ |
| pixelFormat, colorSpaceName | ✅ | StreamConfiguration + native config; optional CVPixelFormatType + color space name |

### Screenshot

| API | Status | Notes |
|-----|--------|-------|
| SCScreenshotManager.captureImage | ✅ | captureScreenshot, macOS 14+ |
| SCScreenshotConfiguration | ✅ | width/height via captureScreenshot |

### System picker

| API | Status | Notes |
|-----|--------|-------|
| SCContentSharingPicker | ✅ | presentContentSharingPicker(); present(), present(using:), isActive, maximumStreamCount; macOS 14+ |
| SCContentSharingPickerConfiguration | ✅ | ContentSharingPickerConfiguration + CaptureStream.setContentSharingPickerConfiguration; setConfiguration(_:for:); macOS 14+ |
| SCContentSharingPickerMode | ✅ | ContentSharingPickerMode enum + allowedModes in present |
| SCContentSharingPickerObserver | ✅ | Used internally in native `picker_start` / main-queue block |

### Errors

| API | Status | Notes |
|-----|--------|-------|
| SCStreamError handling | ✅ | stream_get_last_error + ScreenCaptureKitException(domain, code) on start failure |

## README Roadmap alignment

The package [README](../../../README.md) includes a **Roadmap** section that summarizes capability areas. Use this table to map those bullets to ScreenCaptureKit APIs (all rows below are implemented in the current Dart API unless noted).

| Roadmap / capability area | Coverage target |
|---------------------------|-----------------|
| Window capture | `SCContentFilter(desktopIndependentWindow:)`, `SCWindow` |
| Region capture | Region via `SCStreamConfiguration.sourceRect` |
| Cursor capture | `SCStreamConfiguration.showsCursor` |
| Audio capture | `capturesAudio`, `addStreamOutput` (audio); microphone macOS 15+ |
| Frame rate configuration | `minimumFrameInterval` via `frameRate` parameter |
| Multi-display capture | `SCDisplay`, `createDisplayFilter` |
| System picker | `SCContentSharingPicker`, configuration, mode (macOS 14+) |

## Remaining work (picker subset)

- **System picker:** No further work required for the picker APIs listed in the checklist above.
- **Other framework surface:** See **Optional / not yet covered** below for additional APIs (stream delegate, extra config properties, etc.).

## Optional / not yet covered (spec vs checklist)

Items from the framework spec that are not in the checklist above. Low priority unless needed for a use case.

| Area | API / property | Status | Notes |
|------|----------------|--------|-------|
| Shareable content | getExcludingDesktopWindows(onScreenWindowsOnlyAbove/Below:) | ❌ | Only onScreenWindowsOnly (bool) variant implemented |
| Shareable content | SCShareableContent.getWithCompletionHandler | ❌ | Simpler variant; getExcludingDesktopWindows covers typical use |
| Shareable content | SCShareableContent.info(for:) | ❌ | Content info for a filter |
| Content filter | SCContentFilter(display:including:) | ❌ | Capture only specific windows (include list) |
| Content filter | contentRect, pointPixelScale, streamType, style | ⚠️ | contentRect via sourceRect ✅; pointPixelScale, streamType, style not exposed |
| Stream config | scalesToFit, destinationRect, preservesAspectRatio | ❌ | |
| Stream config | colorMatrix, backgroundColor, shouldBeOpaque | ❌ | |
| Stream config | capturesShadowsOnly, ignoreShadows*, ignoreGlobalClip* | ❌ | |
| Stream config | captureResolution, sampleRate, channelCount | ❌ | sampleRate/channelCount from device; we don't set |
| Stream config | streamName, presenterOverlayPrivacyAlertSetting | ❌ | |
| Stream | SCStreamDelegate | ❌ | Lifecycle callbacks not bridged to Dart |
| Stream | SCStreamFrameInfo / SCFrameStatus | ⚠️ | Used internally; not exposed as Dart API |
| Screenshot | SCScreenshotConfiguration (image quality) | ⚠️ | width/height only; image quality not exposed |

## Usage

1. Before implementing: identify which checklist items the feature touches
2. After implementing: update Status to ✅ and add Notes
3. If user-facing, update README **Features** and/or **Roadmap**; keep this file’s alignment table in sync when roadmap wording changes
