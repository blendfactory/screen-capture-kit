---
name: screen-capture-kit-spec
description: >-
  Reference for Apple ScreenCaptureKit API specification. Use when implementing
  or extending screen-capture-kit package, designing Dart APIs, or verifying
  feature coverage against the native framework.
---

# ScreenCaptureKit API Specification

Reference for implementing full ScreenCaptureKit support in the screen-capture-kit Dart package.

## When to use

- Implementing a new ScreenCaptureKit feature
- Designing Dart API that mirrors native behavior
- Verifying coverage or identifying gaps
- Debugging native bridge issues

## Quick reference

For the full API spec, see [reference.md](reference.md).

## Official resources

| Resource | URL |
|----------|-----|
| Framework overview | https://developer.apple.com/documentation/screencapturekit |
| Capturing guide | https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos |
| WWDC22 Meet ScreenCaptureKit | https://developer.apple.com/videos/play/wwdc2022/10156/ |
| WWDC23 What's new | https://developer.apple.com/videos/play/wwdc2023/10136/ |
| WWDC22 Take to next level | https://developer.apple.com/videos/play/wwdc22/10155 |
| WWDC24 HDR capture | https://developer.apple.com/videos/play/wwdc24/10088 |

## API domains

1. **Shareable content** — `SCShareableContent`, `SCDisplay`, `SCRunningApplication`, `SCWindow`
2. **Content capture** — `SCStream`, `SCContentFilter`, `SCStreamConfiguration`
3. **Output** — `SCStreamOutput`, `SCStreamOutputType`, `SCStreamFrameInfo`, `SCFrameStatus`
4. **Screenshot** — `SCScreenshotManager`, `SCScreenshotConfiguration`, `SCScreenshotOutput`
5. **System picker** — `SCContentSharingPicker`, `SCContentSharingPickerConfiguration`
6. **Errors** — `SCStreamError`, `SCStreamError.Code`

## Platform

- macOS 12.3+
- Requires Screen Recording permission
