# screen_capture_kit example

Sample command-line app demonstrating display, window, region, and system picker capture with `screen_capture_kit`.

## Requirements

- macOS **12.3+** (some flows need **14+**, e.g. screenshot / system picker)
- **Screen Recording** permission (System Settings → Privacy & Security)
- [Dart SDK](https://dart.dev/get-dart) **3.10+** (aligned with the main package)

## Run

From this directory:

```bash
dart pub get
dart run bin/example.dart
```

The app prints menu-style options to stdout. Follow the prompts; grant permissions when macOS asks.

## Project layout

| Path | Role |
|------|------|
| `bin/example.dart` | Interactive demo entrypoint |
| `pubspec.yaml` | Depends on `screen_capture_kit` via `path: ../` |
