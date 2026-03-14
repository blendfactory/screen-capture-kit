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
- When updating README Roadmap
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
| SCStream.addStreamOutput (microphone) | ❌ | config.captureMicrophone captures mic into audio stream; separate type not used |
| SCStream.startCapture | ✅ | |
| SCStream.stopCapture | ✅ | |
| SCStream.updateConfiguration | ✅ | startCaptureStreamWithUpdater + CaptureStream.updateConfiguration |
| SCStream.updateContentFilter | ✅ | CaptureStream.updateContentFilter(ContentFilterHandle) |

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
| SCContentSharingPicker | ❌ | |
| SCContentSharingPickerConfiguration | ❌ | |

### Errors

| API | Status | Notes |
|-----|--------|-------|
| SCStreamError handling | ✅ | stream_get_last_error + ScreenCaptureKitException(domain, code) on start failure |

## README Roadmap alignment

| Roadmap item | Coverage target |
|--------------|-----------------|
| Window capture | SCContentFilter(desktopIndependentWindow:), SCWindow |
| Region capture | SCContentFilter.contentRect |
| Cursor capture | SCStreamConfiguration.showsCursor |
| Audio capture | capturesAudio, addStreamOutput(.audio) |
| Frame rate configuration | minimumFrameInterval |
| Multi-display capture | SCDisplay, createDisplayFilter ✅ |

## Usage

1. Before implementing: identify which checklist items the feature touches
2. After implementing: update Status to ✅ and add Notes
3. Sync README Roadmap when major items are done
