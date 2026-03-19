---
name: screen-capture-kit-feature-add
description: >-
  Workflow for adding a new ScreenCaptureKit feature to the package. Use when
  implementing display capture, window capture, audio, or other features from
  the roadmap or API coverage checklist.
---

# ScreenCaptureKit Feature Add Workflow

Step-by-step workflow for adding a new ScreenCaptureKit feature to the screen-capture-kit Dart package.

## When to use

- Implementing a new feature (e.g. window capture, audio capture)
- Adding a new ScreenCaptureKit API to the Dart surface
- Following [screen-capture-kit-api-coverage](../screen-capture-kit-api-coverage/SKILL.md) gaps or [README Roadmap](../../../README.md#roadmap) notes

## Workflow

### 1. Verify spec and coverage

- Use `screen-capture-kit-spec` for the exact Apple APIs (names and behavior)
- Use `screen-capture-kit-api-coverage` for current status; update the checklist when done

### 2. Design Dart API

- **Naming:** Match Dart conventions (camelCase, clear names)
- **Types:** Map framework types to Dart domain types (see `screen-capture-kit-native-bridge`)
- **Async:** Use `Future` for one-shot, `Stream` for continuous output
- **Errors:** Map failures to `ScreenCaptureKitException` / `UnsupportedError` as appropriate

### 3. Implement native bridge (Objective-C)

- Add or extend `.m` sources under `native/` (compiled via Dart Build Hooks)
- Follow patterns from `screen-capture-kit-native-bridge`:
  - Completion handlers / async native calls → Dart `Future`
  - Stream output callbacks → Dart `Stream` / controllers
  - `CMSampleBuffer` → frame or PCM bytes for Dart
- Ensure Screen Recording permission where needed

### 4. Expose Dart API

- Export public types from `lib/screen_capture_kit.dart` only
- Wire `ScreenCaptureKit` facade and `lib/src/infrastructure/*` implementations
- Document with `///` per `dart-standards.mdc`
- Keep API minimal; avoid unnecessary dependencies

### 5. Update example

- Add or update `example/bin/example.dart` for user-visible behavior
- Ensure it runs on macOS 12.3+ (and document stricter version if the feature needs it)

### 6. Add tests

- Unit tests for Dart logic (use `mocktail` per `dart-standards.mdc`)
- Integration-style tests when feasible (e.g. with permission on macOS)

### 7. Update docs and coverage

- Update README ([Features](../../../README.md#features) / [Roadmap](../../../README.md#roadmap)) if the feature is user-facing
- Update `screen-capture-kit-api-coverage` checklist rows and notes
- Add `CHANGELOG.md` entry under `[Unreleased]` when preparing a release

### 8. Commit

- Follow `commit-message-standards.mdc`
- Use scope `feat(native)` or `feat(api)` as appropriate
- Include reference link in body (e.g. Apple docs)

## Example: Window capture (already shipped — use as reference)

1. **Spec:** `SCContentFilter(desktopIndependentWindow:)`, `SCWindow`, `SCShareableContent.windows`
2. **Dart API:** `getShareableContent()` → `Window` list on `ShareableContent`; `createWindowFilter(Window)` → `FilterId`; `startCaptureStream(filter, outputSize: …)` / `startCaptureStreamWithUpdater(filter, outputSize: …)` → `Stream<CapturedFrame>` / `CaptureStream` (use `FrameSize.zero` or `FrameSize(width:, height:)`)
3. **Native:** `native/content_filter.m`, `native/stream.m`, FFI from `screen_capture_kit_macos.dart`
4. **Docs:** `///` on facade and exported types; README usage flow
5. **Example:** Window path in `example/bin/example.dart`
6. **Tests:** Filter/stream behavior in `test/` where not permission-bound
7. **Coverage:** Mark `SCContentFilter(desktopIndependentWindow:)`, `SCWindow` as ✅ in api-coverage skill
8. **Commit:** e.g. `feat(native): add window content filter for capture`

## Reference

- `screen-capture-kit-spec` — API details
- `screen-capture-kit-native-bridge` — Bridging patterns
- `screen-capture-kit-api-coverage` — Coverage checklist
- `dart-standards.mdc` — Dart conventions
