# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.5] - 2026-03-21

### Added

- **Example CLIs**: Added `screenshot_display` (single-display PNG via `captureScreenshot`), `record_display` (uncompressed BGRA AVI, Dart-only), and `record_display_with_audio` (AVI + PCM WAV → MP4 via ffmpeg) with shared helpers `avi_isolate_recorder` and `pcm_wav_writer`.
- **Example `record_picker_with_audio`**: CLI using `presentContentSharingPicker` with FPS capped to display refresh (default 120), `--audio none|system|mic|both`, and ffmpeg mux to MP4. Optional fixed `--width`/`--height`; otherwise AVI dimensions follow the first captured frame (`deferDimensionsFromFirstFrame` on the shared isolate AVI writer).
- **`CaptureStream.flushPendingAudio`**: Drains native audio queues (system and/or microphone) after the FFI poll loop has stopped. Call after canceling `audioStream` / `microphoneStream` subscriptions and before finalizing WAV files so tail PCM buffers are not discarded.
- **Audio sample timestamps (macOS)**: Native JSON now includes optional `presentationTimeSeconds` and `durationSeconds` from each audio `CMSampleBuffer` (system + microphone). `CapturedAudio` exposes these for timeline-aligned consumers.
- **`CapturedAudio.frameCount`**: Optional frame count from native JSON `numSamples` (`CMSampleBufferGetNumSamples`) when the macOS bridge provides it.
- **`BundleId`**: `extension type` wrapping an application bundle identifier (`String`); used by `RunningApplication.bundleIdentifier` and `ContentSharingPickerConfiguration.excludedBundleIds`.
- **`DisplayRefreshRate`**: `extension type` for a display refresh rate in whole Hz (`unknown` sentinel or validated `1..480`), populated from shareable content (`CGDisplayModeGetRefreshRate`). Reflected in `Display` equality, `hashCode`, and `toString`.

### Changed

- **Breaking**: **`RunningApplication.bundleIdentifier`** is **`BundleId`** (not `String`). **`ContentSharingPickerConfiguration.excludedBundleIds`** is **`List<BundleId>?`** (not `List<String>?`).
- **`Display.refreshRate`** type is **`DisplayRefreshRate`** instead of `double`; use `DisplayRefreshRate.fromNum` when building from raw values.
- **Stream video (macOS)**: `stream_get_next_frame` returns a malloc'd buffer with a small binary header (width, height, `bytesPerRow`, data size) plus raw **BGRA** pixels, instead of a JSON string with base64 payload. Native `StreamFrameHandler` keeps a **bounded queue** of pending video frames.
- **Dart macOS bridge**: `startCaptureStream` / `startCaptureStreamWithUpdater` video delivery uses the raw frame path and **drains multiple frames per event-loop turn** (capped batch + yields) so capture throughput stays high while the isolate/event loop can still make progress.
- **Example `record_display_with_audio`**: System and microphone WAVs are written **sequentially** in capture order again. PTS-based placement had been able to **skip real microphone PCM** when overlap trimming thought the cursor was ahead of the buffer's presentation time—sequential append keeps every native chunk. Optional `CapturedAudio` timestamps remain available for custom alignment in other apps.
- **Audio FFI polling (macOS)**: Increased per-tick audio JSON batch drain limit (`_kMaxAudioChunksPerPollBatch` 24 → 96) so the isolate is less likely to lag the microphone queue.

### Removed

- **Example `example.dart`**: Removed the interactive kitchen-sink demo. Display/window/region capture and screenshots are covered by the dedicated CLI examples (`screenshot_display`, `record_display`, etc.).

### Fixed

- **`presentContentSharingPicker` deadlock (macOS)**: The API was wrapped in `Isolate.run`, so native `picker_present` ran on a worker thread while the bridge used `dispatch_sync(main_queue, …)` — the main isolate waited for the worker and the worker waited for the main queue. The picker now runs `presentContentSharingPickerImpl` on the calling isolate (same pattern as UI requires for AppKit).
- **Picker `nextEventMatchingMask` crash (macOS)**: `picker_start` called `-[NSApplication nextEventMatchingMask:…]` from a Dart worker thread, which is restricted to the main thread. Replaced the AppKit event loop with sleep-polling; observer callbacks are delivered by the system via GCD and do not require explicit event pumping.
- **Content filter registry (macOS)**: `ensureFilterRegistry` used `[NSMutableDictionary dictionary]` (autoreleased); the GCD thread's autorelease pool could drain the dictionary before the Dart thread read it. Switched to `[[NSMutableDictionary alloc] init]` for direct ownership. Also added `@synchronized` to `get_content_filter` for thread-safe reads.
- **Native content-sharing picker API (macOS)**: Used Objective-C API `+[SCContentSharingPicker sharedPicker]` and `defaultConfiguration.allowedPickerModes` + `present` instead of the nonexistent `+[SCContentSharingPicker shared]` and `presentUsing:` (Swift-only names), which caused `NSInvalidArgumentException` at runtime.
- **SCContentSharingPicker UI (macOS)**: Set `picker.active = YES` before `present` (required by Apple's header: the picker UI does not appear otherwise). For CLI tools, set `NSApplication` activation policy to **Accessory** and call `activateIgnoringOtherApps:` so Control Center can show the picker.
- **Audio FFI `timeout_ms == 0` (macOS)**: `stream_get_next_audio` and `stream_get_next_microphone` treated `0` as a **5 second** wait instead of a non-blocking poll (unlike `stream_get_next_frame`). That stalled the event loop and could **starve microphone** delivery when queues ran dry between chunks.
- **Audio shutdown drain**: Canceling `audioStream` / `microphoneStream` subscriptions stopped the Dart poll loop while native queues could still hold PCM data. Call `CaptureStream.flushPendingAudio` after canceling audio subscriptions and before finalizing WAVs so tail buffers are not discarded. The flusher uses capped bursts and yields so it cannot starve timers or break `--duration` while capture is still live.
- **Example `record_display_with_audio`**: After capture, pad the microphone WAV with trailing silence when system audio is stereo Float32 and the mic is mono Float32, so `*_mic.wav` duration matches `*_system.wav`. ScreenCaptureKit often emits **fewer samples per microphone `CMSampleBuffer`** than per system-audio buffer while **callback counts stay paired**, which previously produced about **half the mic wall-clock** in raw PCM.
- **Audio capture (macOS)**: Non-interleaved (planar) PCM from `SCStreamOutputTypeAudio` / `Microphone` no longer uses only the first `AudioBuffer`; channels are interleaved so stereo WAV/ffmpeg mux matches real duration (fixes playback sounding **2× fast**). Planar layout is also detected when `kAudioFormatFlagIsNonInterleaved` is **not** set but `mNumberBuffers == mChannelsPerFrame` and each buffer is single-channel (fixes **mic-only half duration** after mux with system audio).
- **Audio + microphone Dart polling**: Replaced 100 ms blocking FFI reads with short timeouts and per-tick batch draining (same idea as video frames), so system-audio polling no longer **starves the microphone** on the same isolate—avoids mic dropping out mid-recording.
- **Dual audio poll loop**: When both system and microphone capture are enabled, a **single** fair round-robin scheduler drains both streams (shared batch cap lowered to 24 chunks/tick) so independent timers no longer monopolize the isolate and starve video or the other audio stream.
- **Microphone PCM (macOS)**: Mono samples split across multiple 1-channel `AudioBuffer`s are now concatenated (previously only `mBuffers[0]` was copied, roughly **halving** mic WAV duration vs system audio). Edge cases where `CMSampleBufferGetNumSamples` implies more bytes than written are handled by reading from `CMSampleBufferGetDataBuffer` when present.

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

[Unreleased]: https://github.com/blendfactory/screen-capture-kit/compare/v0.0.5...HEAD
[0.0.5]: https://github.com/blendfactory/screen-capture-kit/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/blendfactory/screen-capture-kit/releases/tag/v0.0.4
[0.0.3]: https://github.com/blendfactory/screen-capture-kit/releases/tag/v0.0.3
[0.0.2]: https://github.com/blendfactory/screen-capture-kit/releases/tag/v0.0.2
[0.0.1]: https://github.com/blendfactory/screen-capture-kit/releases/tag/v0.0.1
