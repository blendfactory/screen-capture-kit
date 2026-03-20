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

### Display screenshot to PNG (CLI)

`bin/screenshot_display.dart` lists available displays, lets you pick one (or pass
`--display`), and writes a single PNG into an output directory. Requires macOS
**14+** (same as `captureScreenshot`).

```bash
dart pub get
dart run bin/screenshot_display.dart --out ./captures
# non-interactive: second display
dart run bin/screenshot_display.dart ./captures --display 2
```

### Display screen record to uncompressed AVI (CLI)

`bin/record_display.dart` records a display with `startCaptureStream`, packs
**BGRA** frames into an **uncompressed AVI** (RIFF / `movi` / `idx1`) using Dart
only—no external encoder. Recording stops on **Ctrl+C** or `--duration` / `-t`;
the tool may keep writing queued frames afterward.

Notes:

- Output files are very large; use `--width` / `--height` to downscale if needed.
- `--fps` (1..120, header timebase) is **capped** to `Display.refreshRate`
  when `DisplayRefreshRate.isKnown` is true (e.g. 60 Hz display ⇒ requested
  120 becomes 60).

```bash
dart pub get
dart run bin/record_display.dart --out ./recordings --duration 5 --display 1
dart run bin/record_display.dart ./recordings --display 1 --duration 5 \
  --fps 30 --width 640 --height 360
```

## Project layout

| Path | Role |
|------|------|
| `bin/example.dart` | Interactive demo entrypoint |
| `bin/screenshot_display.dart` | CLI: pick a display, save one PNG to a folder |
| `bin/record_display.dart` | CLI: pick a display, record uncompressed AVI (Dart only) |
| `pubspec.yaml` | Depends on `screen_capture_kit` via `path: ../` |
