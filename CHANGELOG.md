# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.2] - 2026-03-18

### Fixed

- Stream SEGV on cancel: call `removeStreamOutput` before `stopCapture` so no callbacks run during teardown, preventing crash when subscription is cancelled on macOS.

### Changed

- Layered architecture: domain, application, infrastructure, and presentation layers with ports and adapters.
- Domain: value objects for IDs and geometry (`DisplayId`, `WindowId`, `FilterId`, `PixelRect`, `FrameSize`), entities with `@immutable`.
- Application: `ScreenCaptureKitPort` interface and `ScreenCaptureKitImpl` implementation.
- Infrastructure: native bridge (FFI) and stub implementations moved into infrastructure layer.
- Presentation: configuration and DTO-like types (`ContentFilter`, `StreamConfiguration`, etc.) grouped in presentation layer.

## [0.0.1] - 2026-03-14

### Added

- Shareable content API: `getShareableContent()` returning displays, applications, and windows (`Display`, `RunningApplication`, `Window`, `ShareableContent`).
- Content filters: `createWindowFilter(Window)`, `createDisplayFilter(Display, {excludingWindows})`, `releaseFilter(ContentFilterHandle)`.
- Display and window capture: `startCaptureStream()` and `startCaptureStreamWithUpdater()` with configurable width, height, frame rate, source rect (region capture), cursor visibility, queue depth, and optional system audio (macOS 13+) and microphone (macOS 15+).
- Runtime updates: `CaptureStream.updateConfiguration()`, `CaptureStream.updateContentFilter()` for changing stream config or filter without stopping.
- Screenshot: `captureScreenshot(ContentFilterHandle, {width, height})` (macOS 14+).
- System content-sharing picker (macOS 14+): `presentContentSharingPicker({allowedModes})`, `ContentSharingPickerMode` enum, `ContentSharingPickerConfiguration`, and `CaptureStream.setContentSharingPickerConfiguration()` for per-stream picker config.
- Exception type: `ScreenCaptureKitException` with optional domain and code from native errors.
- Stub implementation on non-macOS platforms (throws `UnsupportedError`).
- Dart SDK constraint `^3.10.0` and dependency set (code_assets, ffi, hooks, meta, native_toolchain_c; mocktail, test for dev).

[Unreleased]: https://github.com/blendfactory/screen-capture-kit/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/blendfactory/screen-capture-kit/releases/tag/v0.0.2
[0.0.1]: https://github.com/blendfactory/screen-capture-kit/releases/tag/v0.0.1
