# screen_capture_kit example

Sample command-line apps demonstrating display capture, screenshot, audio recording, and system picker capture with `screen_capture_kit`.

## Requirements

- macOS **12.3+** (some flows need **14+**, e.g. screenshot / system picker)
- **Screen Recording** permission (System Settings → Privacy & Security)
- **ffmpeg** on `PATH` for `record_display_with_audio` / `record_picker_with_audio`
  (e.g. `brew install ffmpeg`)
- **Microphone** permission for microphone capture in `record_display_with_audio`
- [Dart SDK](https://dart.dev/get-dart) **3.10+** (aligned with the main package)

## Run

From this directory:

```bash
dart pub get
```

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

### Display + system audio + microphone → MP4 (CLI, ffmpeg)

`bin/record_display_with_audio.dart` captures a display with **system audio** and
**microphone** (`startCaptureStreamWithUpdater` with `capturesAudio` and
`captureMicrophone`), writes a temporary **BGRA AVI** and **two PCM WAV** files,
then runs **ffmpeg** to produce **H.264 + AAC** MP4. Intermediate files are
deleted unless you pass `--keep-temp`.

Requirements:

- **ffmpeg** available (e.g. Homebrew).
- **macOS 13+** for system audio in ScreenCaptureKit; **macOS 15+** for
  microphone via `SCStreamOutputTypeMicrophone`.
- **Screen Recording** and **Microphone** permissions when prompted.

```bash
dart pub get
dart run bin/record_display_with_audio.dart --out ./recordings --duration 10 --display 1
dart run bin/record_display_with_audio.dart ./recordings --keep-temp
```

### Content-sharing picker → MP4 (CLI, ffmpeg, macOS 14+)

`bin/record_picker_with_audio.dart` opens the **system content-sharing picker**
(`presentContentSharingPicker`), then records the chosen display, window, or app
with **BGRA AVI** + optional **system audio** and/or **microphone**, and muxes
to **H.264 + AAC** MP4 with ffmpeg (same pattern as `record_display_with_audio`).

- **FPS**: defaults to **120** and is **capped** by the highest known display
  refresh rate from `ShareableContent` (same idea as the display record CLIs).
- **Audio**: `--audio none|system|mic|both` (default `both` when omitted).
- **Size**: omit `--width` / `--height` to use the **reference display** size
  (highest known refresh rate, then largest area among connected displays). Or
  pass both for a fixed output size.

Requirements: **macOS 14+** for the picker; **macOS 15+** for microphone;
**ffmpeg** on `PATH`.

The picker is **system UI** (often surfaced via **Control Center** in the menu
bar, per Apple’s ScreenCaptureKit design). If nothing appears in front of the
terminal, open **Control Center** and look for the screen-sharing / capture
controls.

```bash
dart pub get
dart run bin/record_picker_with_audio.dart --out ./recordings --duration 10
dart run bin/record_picker_with_audio.dart ./recordings --audio system --fps 120
dart run bin/record_picker_with_audio.dart ./recordings --width 1920 --height 1080
```

## Project layout

| Path | Role |
|------|------|
| `bin/screenshot_display.dart` | CLI: pick a display, save one PNG to a folder |
| `bin/record_display.dart` | CLI: pick a display, record uncompressed AVI (Dart only) |
| `bin/record_display_with_audio.dart` | CLI: display + system + mic → MP4 via ffmpeg |
| `bin/record_picker_with_audio.dart` | CLI: picker + optional audio → MP4 via ffmpeg |
| `lib/avi_isolate_recorder.dart` | Shared isolate-based AVI writer for the record CLIs |
| `lib/pcm_wav_writer.dart` | PCM → WAV helper for `record_display_with_audio` |
| `pubspec.yaml` | Depends on `screen_capture_kit` via `path: ../` |
