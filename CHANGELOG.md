# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`Display.refreshRate`**: shareable-content JSON from macOS now includes each
  display’s refresh rate (Hz) from `CGDisplayModeGetRefreshRate`; `0` when
  unavailable. Included in `Display` equality / `hashCode` / `toString`.

### Changed

- **Stream video (macOS)**: `stream_get_next_frame` returns a malloc’d buffer
  with a small binary header (width, height, `bytesPerRow`, data size) plus raw
  **BGRA** pixels, instead of a JSON string with base64 payload. Native
  `StreamFrameHandler` keeps a **bounded queue** of pending video frames.
- **Dart macOS bridge**: `startCaptureStream` / `startCaptureStreamWithUpdater`
  video delivery uses the raw frame path and **drains multiple frames per
  event-loop turn** (capped batch + yields) so capture throughput stays high
  while the isolate/event loop can still make progress.

## [0.0.4] - 2026-03-20

### Changed

- **Breaking type updates**: stream configuration and stream APIs now use `FrameRate` (`1..120`) and `QueueDepth` (`1..8`) value objects instead of raw `int` for `frameRate`/`queueDepth`; invalid values throw `ArgumentError`.
- **Breaking API naming updates**: stream output dimension parameter names were renamed from `outputSize` to `frameSize` across `captureScreenshot`, `startCaptureStream`, `startCaptureStreamWithUpdater`, and `StreamConfiguration`.

## [0.0.3] - 2026-03-19

### Removed

- `ScreenCaptureKitPort` and `ScreenCaptureKitImpl`: the public entry type is `ScreenCaptureKit` only. Tests may use `implements ScreenCaptureKit` or a mocking package (see class documentation).
- `ContentFilterHandle`: use `FilterId` directly for `captureScreenshot`, stream APIs, and `releaseFilter`.

### Changed

- Domain layout: `entities/`, `value_objects/` (`geometry/`, `identifiers/`, `capture/`), and `errors/`; shareable-content types and capture configuration types (`ContentFilter`, `StreamConfiguration`, picker types, etc.) are grouped under domain value objects where appropriate.
- **Breaking type updates**: entities use `DisplayId`, `WindowId`, `ProcessId`, `FrameSize`, and `PixelRect` instead of raw primitives; `CapturedFrame` and `CapturedImage` expose `FrameSize` for dimensions.
- **Capture output sizing API updates**: `captureScreenshot`, `startCaptureStream`, and `startCaptureStreamWithUpdater` take `outputSize: FrameSize` instead of separate `width`/`height` integers; `StreamConfiguration` uses `outputSize` for stream output dimensions.
- **FrameSize validation for capture output**: for capture output requests, valid sizes are `FrameSize.zero` (`0×0`, native default) or **both** dimensions strictly positive; mixed `0`/positive pairs throw `ArgumentError`.

### Fixed

- Native bridge: safer cross-thread transfer for frame metadata (C strings) and corrected `@available` branching in the stream path.

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
- Content filters: `createWindowFilter(Window)`, `createDisplayFilter(Display, {excludingWindows})`, `releaseFilter(FilterId)`.
- Display and window capture: `startCaptureStream()` and `startCaptureStreamWithUpdater()` with configurable width, height, frame rate, source rect (region capture), cursor visibility, queue depth, and optional system audio (macOS 13+) and microphone (macOS 15+).
- Runtime updates: `CaptureStream.updateConfiguration()`, `CaptureStream.updateContentFilter()` for changing stream config or filter without stopping.
- Screenshot: `captureScreenshot(FilterId, {width, height})` (macOS 14+).
- System content-sharing picker (macOS 14+): `presentContentSharingPicker({allowedModes})`, `ContentSharingPickerMode` enum, `ContentSharingPickerConfiguration`, and `CaptureStream.setContentSharingPickerConfiguration()` for per-stream picker config.
- Exception type: `ScreenCaptureKitException` with optional domain and code from native errors.
- Stub implementation on non-macOS platforms (throws `UnsupportedError`).
- Dart SDK constraint `^3.10.0` and dependency set (code_assets, ffi, hooks, meta, native_toolchain_c; mocktail, test for dev).

[Unreleased]: https://github.com/blendfactory/screen-capture-kit/compare/v0.0.4...HEAD
[0.0.4]: https://github.com/blendfactory/screen-capture-kit/releases/tag/v0.0.4
[0.0.3]: https://github.com/blendfactory/screen-capture-kit/releases/tag/v0.0.3
[0.0.2]: https://github.com/blendfactory/screen-capture-kit/releases/tag/v0.0.2
[0.0.1]: https://github.com/blendfactory/screen-capture-kit/releases/tag/v0.0.1
