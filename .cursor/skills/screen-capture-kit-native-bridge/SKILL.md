---
name: screen-capture-kit-native-bridge
description: >-
  Patterns for bridging ScreenCaptureKit Swift APIs to Dart. Use when implementing
  new native bindings, converting CMSampleBuffer to Dart, or designing the Swift-Dart
  interface layer.
---

# ScreenCaptureKit Native Bridge

Patterns for bridging Apple ScreenCaptureKit (Swift) to Dart in the screen-capture-kit package.

## When to use

- Implementing a new ScreenCaptureKit API in Swift
- Exposing native callbacks (e.g. frame output) as Dart `Stream`
- Converting `CMSampleBuffer` / `CVPixelBuffer` to Dart-friendly types
- Designing async Swift → Dart communication

## Architecture

```
Dart API (Stream, Future, etc.)
    │
    │  Dart FFI / Build Hooks
    ▼
Swift Bridge
    │
    │  ScreenCaptureKit
    ▼
SCStream, SCShareableContent, etc.
```

## Bridging patterns

### 1. Async Swift → Dart Future

- Swift methods with completion handlers map to Dart `Future<T>`
- Use `withCheckedContinuation` or equivalent in the bridge layer
- Example: `SCShareableContent.getExcludingDesktopWindows(...)` → `Future<ShareableContent>`

### 2. Callbacks → Dart Stream

- `SCStreamOutput.stream(_:didOutputSampleBuffer:of:)` receives `CMSampleBuffer`
- Bridge: maintain a `StreamController` in Dart, push from Swift callback
- Ensure callback runs on correct isolate; use `IsolateNameServer` or similar if needed

### 3. CMSampleBuffer handling

- Video: `CMSampleBufferGetImageBuffer` → `CVPixelBuffer` → `IOSurface`
- Metadata: `CMSampleBufferGetSampleAttachmentsArray` + `SCStreamFrameInfo` keys
- Check `SCFrameStatus.complete` before processing
- Audio: `CMSampleBuffer` → `AVAudioPCMBuffer` (or raw buffer list) for PCM data

### 4. Type mapping

| Swift | Dart |
|-------|------|
| `SCDisplay` | `Display` (id, width, height, etc.) |
| `SCWindow` | `Window` (id, frame, app, etc.) |
| `SCRunningApplication` | `RunningApplication` (bundleId, name, etc.) |
| `SCContentFilter` | `ContentFilter` (config object) |
| `SCStreamConfiguration` | `StreamConfiguration` (config object) |
| `CMSampleBuffer` | Raw bytes or `Uint8List` / custom frame type |
| `CVPixelBuffer` | `Uint8List` (BGRA) or platform-specific handle |

### 5. Error handling

- Map `SCStreamError` / `SCStreamError.Code` to Dart `Exception` or custom error type
- Propagate errors through `Future` or `Stream` error channel

### 6. Lifecycle

- Ensure `SCStream.stopCapture()` when Dart stream is cancelled
- Release native resources when Dart object is disposed

## Build Hooks

This package uses Dart Build Hooks for native compilation. Native Swift code lives in the package's native asset directory and is compiled during `dart pub get` or build.

Ref: https://dart.googlesource.com/native/+/refs/heads/main/pkgs/hooks

## Reference

- Use `screen-capture-kit-spec` skill for full API details
- Apple sample: https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos
