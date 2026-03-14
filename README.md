# screen_capture_kit

Native Dart bindings for macOS ScreenCaptureKit using Dart Build Hooks.

`screen_capture_kit` provides high-performance access to Apple's ScreenCaptureKit API from Dart applications.  
It enables screen, window, and display capture on macOS with minimal overhead by calling the native APIs directly.


[![pub version](https://img.shields.io/pub/v/screen_capture_kit.svg)](https://pub.dev/packages/screen_capture_kit)
[![license](https://img.shields.io/github/license/blendfactory/screen-capture-kit)](LICENSE)

## Features

- Native macOS screen capture
- Window capture
- Display capture
- High performance frame streaming
- Powered by Dart Build Hooks
- No Flutter dependency (pure Dart support)

## Platform Support

| Platform | Support |
|--------|--------|
| macOS | ✅ |
| Windows | ❌ |
| Linux | ❌ |
| iOS | ❌ |
| Android | ❌ |

macOS 12.3 or later is required.

## Installation

Add the package:

```bash
dart pub add screen_capture_kit
````

## Example

```dart
import 'package:screen_capture_kit/screen_capture_kit.dart';

void main() async {
  final capture = ScreenCaptureKit();

  await capture.requestPermission();

  await capture.startDisplayCapture();

  capture.frames.listen((frame) {
    print('Frame received: ${frame.width}x${frame.height}');
  });
}
```

## Architecture

This package uses Dart Build Hooks to compile native macOS code and bridge the ScreenCaptureKit APIs to Dart.

```
Dart
 │
 │  Dart API
 ▼
Native Bridge
 │
 │  Swift
 ▼
ScreenCaptureKit
```

This design allows low-latency frame capture while keeping the Dart API simple.

## Roadmap

* [x] Window capture
* [x] Region capture
* [x] Cursor capture
* [ ] Audio capture
* [x] Frame rate configuration
* [x] Multi-display capture

## Example Apps

See the `example/` directory for a working sample.

## Contributing

Contributions are welcome.

If you find bugs or have feature requests, please open an issue.

## License

BSD 3-Clause License
