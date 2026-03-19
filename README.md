# ScreenCaptureKit for Dart

Native Dart bindings for macOS ScreenCaptureKit using Dart Build Hooks.

`screen_capture_kit` provides high-performance access to Apple's ScreenCaptureKit API from Dart applications.  
It enables screen, window, and display capture on macOS with minimal overhead by calling the native APIs directly.

[![pub version](https://img.shields.io/pub/v/screen_capture_kit.svg)](https://pub.dev/packages/screen_capture_kit)
[![license](https://img.shields.io/github/license/blendfactory/screen-capture-kit)](LICENSE)

## Features

- **Display capture** — Capture entire displays or regions
- **Window capture** — Capture individual windows
- **Region capture** — Crop to a specific area via `sourceRect`
- **Screenshot** — Single-frame capture (macOS 14+)
- **System picker** — Native content-sharing picker UI (macOS 14+)
- **Audio capture** — System audio (macOS 13+), optional microphone (macOS 15+)
- **Cursor capture** — Include or hide the system cursor
- **Frame rate configuration** — 1–120 fps
- **Multi-display** — Capture any connected display
- **Powered by Dart Build Hooks** — No Flutter dependency (pure Dart support)

## Platform Support

| Platform | Support |
|----------|---------|
| macOS | ✅ |
| Windows | ❌ |
| Linux | ❌ |
| iOS | ❌ |
| Android | ❌ |

macOS 12.3 or later is required. Screenshot and system picker require macOS 14+.  
Audio capture requires macOS 13+; microphone capture requires macOS 15+.

## Installation

Add the package:

```bash
dart pub add screen_capture_kit
```

## Example

```dart
import 'package:screen_capture_kit/screen_capture_kit.dart';

void main() async {
  final kit = ScreenCaptureKit();
  final content = await kit.getShareableContent();

  if (content.displays.isEmpty) return;

  final display = content.displays.first;
  final filter = await kit.createDisplayFilter(display);

  kit.startCaptureStream(filter, width: display.width, height: display.height)
      .listen((frame) {
    print('Frame: ${frame.size.width}x${frame.size.height}');
  });

  // Call kit.releaseFilter(filter) when done
}
```

## Usage flow

1. **Get shareable content** — `getShareableContent()` returns displays, windows, and applications.
2. **Create a content filter** — `createDisplayFilter()` or `createWindowFilter()` for the target.
3. **Start capture** — `startCaptureStream()` for frames, or `startCaptureStreamWithUpdater()` for runtime config changes and audio.
4. **Release** — Call `releaseFilter(filter)` with the same `FilterId` you used for capture.

For screenshots, use `captureScreenshot(filter)` (pass the `FilterId` from `createDisplayFilter` / `createWindowFilter` / the picker flow). For the system picker, use `presentContentSharingPicker()`.

## Architecture

This package uses Dart Build Hooks to compile native macOS code and bridge the ScreenCaptureKit APIs to Dart.

**Dart layers** (inward dependencies): **domain** (entities, value objects, errors) → **application** (`ScreenCaptureKit` facade) → **infrastructure** (macOS FFI + stub). **Presentation** holds stream-facing types such as `CaptureStream`. The public barrel exports domain types and the facade only.

```
Dart (barrel + ScreenCaptureKit)
 │
 │  FFI
 ▼
Native bridge (Objective-C)
 │
 ▼
ScreenCaptureKit (Apple framework)
```

This design allows low-latency frame capture while keeping the Dart API simple.

## Example app

See the `example/` directory for a full sample including display, window, region, and system picker capture. Run instructions: [example/README.md](example/README.md).

## Roadmap

Major capability areas are **implemented** and listed under [Features](#features): display/window capture, region crop via `sourceRect`, cursor visibility, system and microphone audio (where supported by macOS version), frame rate, multi-display, screenshot (macOS 14+), and the system content-sharing picker (macOS 14+).

**Not exposed** in the Dart API today includes many optional framework knobs (e.g. `SCStreamDelegate`, several advanced `SCStreamConfiguration` properties, include-only window filters). Maintainers track those gaps in the repository checklist [`.cursor/skills/screen-capture-kit-api-coverage/SKILL.md`](.cursor/skills/screen-capture-kit-api-coverage/SKILL.md).

## Additional documentation

- [Contributing](CONTRIBUTING.md) — setup, tests, and PR guidelines
- [Domain model](doc/domain-model.md) — aggregate root, entities, and value objects
- [Intended use cases](doc/intended-use-cases.md) — capture-only scope and typical pipelines
