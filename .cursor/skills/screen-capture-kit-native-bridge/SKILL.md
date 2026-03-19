---
name: screen-capture-kit-native-bridge
description: >-
  Patterns for bridging ScreenCaptureKit to Dart. Use when implementing native
  bindings in Objective-C, converting CMSampleBuffer to Dart, or designing the
  native–Dart interface layer.
---

# ScreenCaptureKit Native Bridge

Patterns for bridging Apple **ScreenCaptureKit** (called from **Objective-C** in this package) to Dart via **FFI** and **Dart Build Hooks**.

## When to use

- Implementing a new ScreenCaptureKit API in `native/*.m`
- Exposing native callbacks (e.g. frame output) as Dart `Stream`
- Converting `CMSampleBuffer` / `CVPixelBuffer` to Dart-friendly types
- Designing async native → Dart communication

## Architecture

```
Dart API (Stream, Future, ScreenCaptureKit facade)
    │
    │  FFI (C symbols) + Dart Build Hooks
    ▼
Objective-C bridge (native/*.m)
    │
    │  ScreenCaptureKit framework
    ▼
SCStream, SCShareableContent, etc.
```

Apple documents APIs in Swift; Objective-C method names map to the same underlying classes.

## Bridging patterns

### 1. Async native → Dart Future

- APIs with completion handlers (blocks) in Objective-C map to Dart `Future<T>` via the FFI layer and isolates where used
- Example: `SCShareableContent` fetch → `Future<ShareableContent>` (`getShareableContent`)

### 2. Callbacks → Dart Stream

- `SCStreamOutput` sample-buffer callbacks receive `CMSampleBuffer`
- Bridge: forward into Dart-side streaming (e.g. `StreamController` or native queue drained from Dart)
- Respect teardown order (e.g. remove stream output before `stopCapture`) to avoid callbacks after cancel

### 3. CMSampleBuffer handling

- Video: `CMSampleBufferGetImageBuffer` → `CVPixelBuffer` → BGRA bytes for Dart
- Metadata: `CMSampleBufferGetSampleAttachmentsArray` + `SCStreamFrameInfo` keys where needed
- Check frame status (e.g. complete) before processing when required
- Audio: convert to PCM `Uint8List` for Dart consumers

### 4. Type mapping

| Framework (conceptual) | Dart |
|------------------------|------|
| `SCDisplay` | `Display` (`DisplayId`, `FrameSize`) |
| `SCWindow` | `Window` (`WindowId`, `PixelRect`, `RunningApplication`, …) |
| `SCRunningApplication` | `RunningApplication` (`ProcessId`, bundle id, name) |
| `SCContentFilter` | `ContentFilter` / `FilterId` after creation |
| `SCStreamConfiguration` | `StreamConfiguration` |
| `CMSampleBuffer` (video) | `CapturedFrame` / raw `Uint8List` BGRA |
| `CMSampleBuffer` (audio) | `CapturedAudio` / PCM bytes |

### 5. Error handling

- Map `SCStreamError` / failure paths to `ScreenCaptureKitException` (domain/code) or `UnsupportedError` on unsupported OS versions
- Propagate through `Future` or `Stream` error channels

### 6. Lifecycle

- Call `SCStream.stopCapture` when the Dart subscription ends
- Release native resources and invalidates when filters are released from Dart

## Build Hooks

Native Objective-C sources live in `native/` and are built through **Dart Build Hooks** (`hooks/`, `code_assets`, `native_toolchain_c`).

Ref: https://dart.googlesource.com/native/+/refs/heads/main/pkgs/hooks

## Reference

- Use `screen-capture-kit-spec` skill for full API details
- Apple sample: https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos
