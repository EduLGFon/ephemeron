# TODO

## Completion pass (2026-11-12/13)

Every code-actionable item that was open in this file is closed. Summary:

- Calendar and sync: Microsoft shared calendars (shared scope, owner stamping,
  one reader per shared calendar, 403 reconsent); repeatable device-calendar
  import with ID-only mappings, safe reconciliation, and mapping pruning;
  Google single-occurrence push with exception outbox, generated-instance
  lookup, etag/412 retry, and deleted-instance relink; per-account Google token
  restore with a proactive reconnect banner; shared-calendar owner/reader
  election; Microsoft remote calendar and windowed event deletion
  reconciliation with tombstone revival; read-only enforcement at the
  repository boundary and in details/timeline/editor UI; single-occurrence
  alert, edit-target, and location/Meet inheritance integrity; sync issues
  diagnostics with retry/discard; fail-closed shared dedupe; stale reader-key
  and legacy token cleanup; reconnect-banner first-frame fix; startup rebuild
  coalescing.
- Schema and data: occurrence-cache source labels and accounts (Drift schema
  v14) with a v13 to v14 migration; step-by-step v11/v12/v13 to v14 migration
  replay tests; source labels rendered in timeline, agenda, and month surfaces.
- Tasks and notes: parent moves carry the live subtask tree in one transaction;
  projected task occurrence uncomplete has a 6-second calendar undo; Markdown
  fenced and indented code hardening; recurring-split description-link cleanup
  and deterministic reverse sync; duplicate description write/outbox removal;
  dead note-overflow helpers removed.
- UX and accessibility: 48dp habit action targets at 320dp and 2x text; shared
  tag-limit constant and per-group search error/retry; cached alarm permission
  futures with refresh after Settings and on resume; Done/+1 haptics after
  action success; biometric lock screen uses the app theme; task-list chip
  touch long-press management; coverage for habit agenda/Open habits,
  long-press drag reorder, large accessibility text, and the sync final-status
  matrix; all-day strip and month long-press quick create.
- Build and refactor: AGP 9.3.3 and Gradle 9.5.1 with a recorded size and
  behavior comparison; auth logging privacy cleanup; large UI and data modules
  split into `part` files with behavior preserved.
- Verification: `flutter pub get`, `flutter gen-l10n`,
  `dart run tools/gen_test_runner.dart`, `dart format --set-exit-if-changed .`,
  `flutter analyze`, and the full `flutter test` suite on the merged tree.
  Arm64 release APK rebuilt and recorded below.

## Open: owner/device verification (no devices or SDKs here)

- Week calendar home widget: Android native build and launcher behavior;
  warm/cold launcher tap navigation; Motorola One Fusion 4x2 setup dialog.
- Android alarm ring flow: `AlarmRingService` audio and flashlight on device;
  cold/warm notification taps open `/ring`; Snooze/Dismiss/Open item stop
  native audio; Android 14+ without full-screen intent permission; alarms with
  notifications disabled are marked missed; locked-device full-screen ring
  over the keyguard with biometric lock on; minute repeats do not re-alert.
- Native notification Dismiss does not run Dart, so the next habit occurrence
  is scheduled on the next app open (no headless alarm-window rebuild).
- Google sign-in and runtime permissions on Android debug and release, decline
  path, device-calendar import/settings, first reminder/alarm prompts,
  exact-alarm and full-screen prompts. Google Cloud console steps still
  required: SHA-1 entries, Calendar/Tasks APIs, Web `serverClientId` match.
- Microsoft web sign-in: Entra SPA redirect registration for
  `http://localhost:8080/auth.html` (owner console). Android is the primary
  verification target.
- Real-account checks: shared Google and Microsoft calendars, freeBusyReader
  calendars, recurring exceptions moved/cancelled, Google single-occurrence
  edit/delete, multi-account restart and reconnect banner, device-calendar
  refresh, force-sync error paths.
- Visual/device checks: light/dark/AMOLED theme, More command center,
  onboarding, quick add, search, calendar, tasks, notes/auth, habits/focus/
  countdowns, alarm ring navigation, matrix density and peek at 2.5x/3x text,
  notes grid performance, 320dp large-text layouts.
- Device profile run for startup and calendar rebuild timings.

## Open: owner console, legal, and store

- Security review code-level done (`docs/SECURITY_REVIEW.md`); Play
  declarations, backup rules, and release-build verification are owner checks.
- Privacy policy draft done (`docs/PRIVACY.md` EN/PT); needs lawyer sign-off.
- Store assets and staged rollout: owner.
- iOS: home-screen widgets require a WidgetKit extension, App Group
  entitlement, signing, and SwiftUI views (`docs/IOS_WIDGETS.md`); Critical
  Alerts requires the entitlement and App Store Connect request. Both need
  macOS + Xcode.

## Accepted limitations and deliberate decisions

- The UI remains English-only by decision. `intl` handles formatting and only
  the existing ARB keys are localized; a full localization pass is a separate
  owner-approved effort.
- Google has no single-token cross-account move. Moving a recurring Google
  series to a local calendar is supported; cross-account copy/delete requires
  both accounts to have synced at least once.
- Microsoft shared-primary calendars that do not appear in `/me/calendars` are
  not enumerable without the owner address.
- The initial unbounded Google full sync can be heavy on very large calendars.
- Expired Google tokens still require an interactive reconnect. The plugin may
  restore only one lightweight account at a time.
- Device calendars use a manual refresh with a fixed `[now-30d, now+365d]`
  window. Rows that drift outside it are soft-deleted; there is no background
  live device sync (battery and API cost).
- Microsoft deletion reconciliation skips recurring rows and rows with
  unprovable overlap; they are left untouched rather than guessed.
- Sync diagnostics show only non-personal allowlisted labels. Outbox payloads,
  tokens, emails, titles, and raw response bodies are never rendered.
- Notes' relative "Saved Xm ago" label refreshes on rebuild rather than a live
  timer, to avoid periodic wakeups.
- Native notification Dismiss schedules the next habit occurrence on the next
  app open (no headless worker).
- `wakelock_plus` stays at 1.8.0: 1.8.2 conflicts with `battery_plus` 7.1.2
  via `dbus`. Revisit when either package relaxes.
- Do not run a release build while `flutter run` is active; both rewrite
  `GeneratedPluginRegistrant.java`, and the debug registrant includes
  `integration_test`, which breaks the release Java compile.

## Verification record (2026-11-13)

- `flutter pub get`, `flutter gen-l10n`, and
  `dart run tools/gen_test_runner.dart` (116 case files) succeeded.
- `dart format --set-exit-if-changed .` clean (526 files, 0 changed).
- `flutter analyze` clean, no issues.
- Full `flutter test` passed: 773 tests.
- Arm64 release APK:
  `app/build/app/outputs/flutter-apk/app-release.apk`, 27,831,621 bytes
  (27.8 MB), `libapp.so` only under `lib/arm64-v8a`, SHA-256
  `f52ce3b62f08a140cf16110ab6c0f65cd20f7eb48f74c36c6ab45b9c77abb92d`.
  Built with `flutter build apk --release --target-platform android-arm64`
  and temporary non-committed dart-defines for the platform OAuth client IDs.
- Pre-existing Drift multiple-database debug warnings appear in the test run
  and do not affect results.
