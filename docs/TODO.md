# TODO

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
