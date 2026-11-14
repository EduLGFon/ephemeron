# Ephemeron

Offline-first productivity app: calendar, tasks, habits, countdowns, focus, notes, lists. Flutter. Android first; Linux, Web, Windows, iOS, macOS supported. Google sync and optional email backend sync are optional.

## Setup

Verified toolchain: Flutter 3.50.0 stable, Dart 3.14.0. Pubspec minimums: Flutter >=3.47.0, Dart >=3.13.0.

```
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Backend (habits/focus sync) is separate: see `server/README.md` and `docs/DOCKER.md`.

## Commands

- Format: `dart format .`
- Analyze: `flutter analyze`
- Tests: `flutter test` (single entrypoint `test/all_test.dart`; cases in `test/cases/*_case.dart`)
- Regenerate test runner: `dart run tools/gen_test_runner.dart`
- Codegen: `dart run build_runner build --delete-conflicting-outputs`
- Builds: `flutter build appbundle`, `flutter build web --release`, `flutter build linux`, `flutter build windows`

## Docs

- `AGENTS.md` - agent/workspace rules.
- `ARCHITECTURE.md` - design contract.
- `docs/` - feature specs, API, deploy, privacy, security, TODO, progress.