# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **Example `record_display_with_audio`**: After capture, pad the microphone WAV
  with trailing silence when system audio is stereo Float32 and the mic is mono
  Float32, so `*_mic.wav` duration matches `*_system.wav`. ScreenCaptureKit
  often emits **fewer samples per microphone `CMSampleBuffer`** than per
  system-audio buffer while **callback counts stay paired**, which previously
  produced about **half the mic wall-clock** in raw PCM.

- **Audio capture (macOS)**: Non-interleaved (planar) PCM from
  `SCStreamOutputTypeAudio` / `Microphone` no longer uses only the first
  `AudioBuffer`; channels are interleaved before base64 JSON so stereo WAV/FFmpeg
  mux matches real duration (fixes playback sounding **2× fast**). Planar layout
  is also detected when `kAudioFormatFlagIsNonInterleaved` is **not** set but
  `mNumberBuffers == mChannelsPerFrame` and each buffer is at most one channel
  (fixes **mic-only half duration** after mux with system audio).

- **Audio + microphone Dart polling**: Replaced 100 ms blocking FFI reads with
  short timeouts and per-tick batch draining (same idea as video frames), so
  system-audio polling no longer **starves the microphone** on the same
  isolate—avoids mic dropping out mid-recording.

- **Dual audio poll loop**: When both system and microphone capture are enabled,
  a **single** fair round-robin scheduler drains both streams (shared batch cap
  lowered to 24 chunks/tick) so independent timers no longer monopolize the
  isolate and starve video or the other audio stream.

- **Microphone PCM (macOS)**: Mono samples split across multiple 1-channel
  `AudioBuffer`s are concatenated (previously only `mBuffers[0]` was copied,
  roughly **halving** mic WAV duration vs system audio).

- **Microphone PCM (macOS)**: After interleaving/concat in `BuildInterleavedPCM`,
  mic output is widened when summed buffer sizes still exceed `pcm` length
  (mono concat bypassing per-buffer `mNumberChannels` edge cases), and when
  `CMSampleBufferGetNumSamples` implies more bytes than written, copy from
  `CMSampleBufferGetDataBuffer` when present so WAV duration can match system
  audio.

- **Dual audio scheduling**: Unified poll drains **microphone before** system
  for each inner iteration and starts the alternating 1 ms blocking wait on
  **mic**, reducing native mic backlog drops.

### Added

- **`CapturedAudio`**: Optional `frameCount` from native JSON `numSamples`
  (`CMSampleBufferGetNumSamples`) when the macOS bridge provides it.

- **`BundleId`**: `extension type` wrapping an application bundle identifier
  (`String`); used by `RunningApplication.bundleIdentifier` and
  `ContentSharingPickerConfiguration.excludedBundleIds`.

- **`DisplayRefreshRate`**: `extension type` for a display refresh rate in whole
  Hz (`unknown` sentinel or validated `1..480`), populated from shareable
  content (`CGDisplayModeGetRefreshRate`). Reflected in `Display` equality,
  `hashCode`, and `toString`.

### Changed

- **Breaking**: **`RunningApplication.bundleIdentifier`** is **`BundleId`**
  (not `String`). **`ContentSharingPickerConfiguration.excludedBundleIds`**
  is **`List<BundleId>?`** (not `List<String>?`).

- **`Display.refreshRate`** type is **`DisplayRefreshRate`** instead of
  `double`; use `DisplayRefreshRate.fromNum` when building from raw values.

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
