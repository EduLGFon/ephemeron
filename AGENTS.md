Global defaults: ~/.config/opencode/AGENTS.md

## Identity
- Ephemeron: offline-first Flutter productivity app (calendar, tasks, habits, countdowns, focus, notes, lists); optional Google sync and optional Deno/Hono/Postgres backend.
- Stack: Flutter 3.50.0 stable / Dart 3.14.0; Android max, Linux+Web medium, Windows low, iOS/macOS supported. No backend in the app; backend auth via HttpBackendAuthRepository.
- Package manager: flutter pub (`flutter pub get`); pubspec.lock gitignored. Codegen: build_runner for Drift; test runner via `dart run tools/gen_test_runner.dart`.
- Canonical docs: `ARCHITECTURE.md` (design contract), `README.md` (setup/version pins), `docs/PRINCIPLES.md`, `docs/PRIVACY.md`, `DECISIONS.md`.

## Commands
- Setup: `cd app && flutter pub get && dart run build_runner build --delete-conflicting-outputs`
- Format: `dart format .` (or `dart format --output=none --set-exit-if-changed .`)
- Analyze: `flutter analyze` (must pass without warnings/errors)
- Tests: `flutter test` (entrypoint `test/all_test.dart`; cases `test/cases/*_case.dart`); targeted `flutter test test/cases/<file>_case.dart`; regenerate runner `dart run tools/gen_test_runner.dart`
- Codegen: `dart run build_runner build --delete-conflicting-outputs`
- Builds: `flutter build appbundle`, `flutter build web --release`, `flutter build linux`, `flutter build windows`
- Backend: see `server/README.md` and `docs/DOCKER.md`

## Map
- `app/lib/`: feature-first layers `domain/`, `data/`, `application/`, `presentation/`; shared UI kit `core/design`; adaptive shell. See `ARCHITECTURE.md`.
- `app/test/cases/`: `_case.dart` files; `test/all_test.dart` generated.
- `tools/`: agent helper scripts (incl. gen_test_runner.dart).
- `server/`: optional Deno/Hono/Postgres backend.

## Invariants
- Single owners: `AlarmScheduler` schedules OS alarms/notifications; `SafeSecureStorage` owns tokens; `core/config/app_config.dart` owns client config; `core/design` is the shared UI kit.
- Privacy architecture: Google tokens/Calendar/Tasks never touch the backend; backend only custom app data (habits, focus, notes, countdowns). Tokens only in flutter_secure_storage via SafeSecureStorage.
- No second local DB beyond Drift/SharedPreferences/flutter_secure_storage. No runtime network fetch of fonts/assets; bundle locally.
- Domain imports no Flutter/Drift/networking; UI reads Drift streams; writes are optimistic local + outbox.
- Soft-delete tasks (`isDeleted`). Drift schema changes via migrations (increment schemaVersion + MigrationStrategy); never edit a shipped migration.
- Web uses hash URLs and keeps initial bundle under 2 MB gzip.
- Platform priority Android max, Linux+Web medium, Windows low, iOS/macOS supported; platform stubs compile on all targets; unsupported features degrade gracefully.
- Test runner guard: `test/all_test.dart` is generated; case files must be registered via `dart run tools/gen_test_runner.dart`.
- Bundle budget and performance budgets: see `ARCHITECTURE.md` and `docs/PRINCIPLES.md`.

## Do not touch
- Do not edit generated files (`*.g.dart`, `test/all_test.dart`); regenerate via build_runner/gen_test_runner.
- Do not touch `SUPER_TASK.md`, `TASKS_UI.md` (untracked task artifacts).
- Do not touch code, feature docs, or `.opencode/` for doc-only work.

## Verify
- `dart format .` clean
- `flutter analyze` no warnings/errors
- `flutter test`
- `flutter build web --release` / `flutter build appbundle` when relevant
- Drift changes: regenerate, analyze, tests; alarms/platform channels: stubs compile.

## Overrides
- None beyond the project-specific invariants above. Generic rules (code quality, security baseline, testing, docs, git, shell efficiency) are global; see `~/.config/opencode/AGENTS.md`.
- Pointer: global defaults loaded from `~/.config/opencode/AGENTS.md`.
