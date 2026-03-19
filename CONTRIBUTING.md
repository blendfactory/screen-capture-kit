# Contributing

Thank you for helping improve `screen_capture_kit`.

## Development setup

- **Dart SDK** `^3.10.0` (see `pubspec.yaml`)
- **macOS** with Screen Recording permission for integration-style checks

Clone the repository, then from the package root:

```bash
dart pub get
dart test
```

To try the sample app:

```bash
cd example
dart pub get
dart run bin/example.dart
```

## Pull requests

- Keep changes focused; prefer small PRs for reviewability.
- Run `dart format .` and `dart test` before submitting.
- Follow [Conventional Commits](https://www.conventionalcommits.org/) for commit messages (see `.cursor/rules/commit-message-standards.mdc` in this repo).
- Document public API changes in `CHANGELOG.md` under `[Unreleased]` when behavior or surface changes.

## Architecture

Layering and domain rules are described in:

- `doc/domain-model.md`
- `.cursor/rules/architecture-ddd-layered.mdc`

New ScreenCaptureKit surface area should stay **capture-only** (see `doc/intended-use-cases.md`).

## Reporting issues

Use [GitHub Issues](https://github.com/blendfactory/screen-capture-kit/issues). Include macOS version, Dart SDK version, and minimal reproduction steps where possible.
