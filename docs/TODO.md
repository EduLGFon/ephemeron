# TODO

## Gap closures (2026-11-12)

- Implemented: Microsoft shared calendars (`Calendars.Read.Shared` requested,
  `isSharedWithMe`/owner stamping, one reader per shared calendar, shared 403
  reconsent); repeatable device-calendar import (`device:` mirror rows,
  recurring series grouped to one master, dirty local edits preserved, safe
  soft-delete reconciliation, persisted ID-only mappings, user-initiated
  refresh); Google single-occurrence push (exception outbox, generated-instance
  lookup, patch/delete with etag and 412 retry, deleted-instance relink,
  re-edit restore, resetExceptions queue cleanup); per-account Google token
  restore after restart with proactive reconnect banner; shared Google calendar
  owner/reader election so each shared calendar is pulled once.
- Verification: `flutter analyze` clean; `dart format --set-exit-if-changed .`
  clean; full `flutter test` passed (673 tests) on master; arm64 release APK
  built at `app/build/app/outputs/flutter-apk/app-release.apk`, 27.7 MB, only
  `lib/arm64-v8a/libapp.so`, SHA-256
  `d26c345f1fde1950a53bd6a983734ce06eb7cc0427fa0398f74ba2dbe8b9298e`.
- Owner/device verification pending: real Microsoft shared calendars after the
  new scope consent, Google single-occurrence edit/delete on a real recurring
  event, app restart with multiple Google accounts and the reconnect banner,
  Android device-calendar refresh.
- Residual limitations: existing Microsoft tokens need one reconnect to obtain
  `Calendars.Read.Shared`; Graph shared-primary calendars that do not appear in
  `/me/calendars` still require the owner address and are not enumerable;
  device refresh is manual and uses the default [now-30d, now+365d] window, so
  rows that drift outside it are soft-deleted; device mappings for calendars
  deselected in a later import are not pruned (only deleted targets are
  pruned); a Google single-occurrence push whose instance Google never exposes
  stays queued with backoff and is reported as a failed change; accounts whose
  cached Google token expired still need interactive reconnect, and the plugin
  may restore only one lightweight account; stale shared-calendar reader keys
  can remain in `syncState`; when `signedInAccounts` is null the shared-calendar
  dedupe fails open and may pull once per account.

## Calendar/sync/notes verification (2026-11-11)

- Implemented: occurrence-cache duplicate fix (all-day recurrence window clamp,
  dedupe, day-key delete), Google recurring exceptions (timed/all-day
  moved/cancelled), unbounded one-time Google full resync via `cal:v2` tokens,
  calendarList pagination, per-calendar failure isolation, truthful force-sync
  messages, timeline tap/long-press 30-min selection with cross-day overlay,
  last event calendar/task list memory, matrix taller scrollable quadrants with
  14px next-task peek and compact tray, notes default square preview grid with
  persisted list toggle.
- Verification: `flutter analyze` clean; full `flutter test` passed (594 tests)
  on master; targeted units passed; `dart format --set-exit-if-changed .` clean.
- Owner/device verification pending: real shared-calendar sync (Google
  multi-account and Microsoft), recurring exceptions moved/cancelled,
  force-sync error paths, tap/long-press selection vs swipe/scroll on device,
  matrix peek/scroll at large text, notes grid performance with many notes.
- Closed 2026-11-12: Microsoft shared calendars and repeatable device-calendar
  import; see Gap closures.
- Deferred: sync notifier final-status matrix tests are partly deferred; initial
  unbounded Google full sync can be heavy on very large calendars; legacy
  `syncState` token rows may remain stale on old installs.

## Calendar/sync follow-up verification (2026-11-12)

- Implemented: matrix task rows compact (~40 px at 1x) with taller quadrants and
  a compact Unclassified tray; event editor keeps an autosaved draft's content
  but ignores its timing when the user tapped/dragged an explicit slot; calendar
  views render a loading/error state for a new range and then the complete
  occurrence set atomically; Google sync isolates push/discovery/calendar/task
  failures, pulls shared calendars readable by any signed-in account, skips
  freeBusyReader, classifies auth/rate/network/server errors, revives cancelled
  tombstones, selects RRULE among recurrence lines, and clears stale v2 tokens on
  410; Google tokens are account-bound; global reconnect banner plus truthful
  force-sync and last-success messages.
- Verification: `flutter analyze` clean; `dart format --set-exit-if-changed .`
  clean; full `flutter test` passed (635 tests) on master.
- Owner/device verification pending: real multi-account shared calendars (Google
  and Microsoft), freeBusyReader calendars, reconnect banner after revoked grant
  and after app restart, tapped/dragged slot on device, matrix density at
  2.5x/3x text.
- Deferred: the persisted reconnect banner may still flash one frame on cold
  start. See Gap closures for the remaining shared-calendar, device import,
  Google single-occurrence, and token restore limitations.

## Owner / device verification (no SDK/devices here)

- Week calendar home widget: verify Android native build and launcher behavior.
- Week widget tap navigation: warm/cold launcher tap behavior still needs owner
  device verification (app-shell restore race fix applied, unverified).
- Android alarm `AlarmRingService` (flashlight blink + MediaPlayer on alarm
  stream) implemented; verify on device (reminder/notification presets unchanged).
- Android alarm ring flow: verify cold/warm notification taps open `/ring`,
  Snooze/Dismiss/Open item stop native audio, Android 14+ without full-screen
  intent permission, and notifications-disabled alarms are marked missed
  instead of ringing without a stop control.
- Full-screen alarm hardening (2026-11-11): on a locked device verify a firing
  alarm opens the Flutter ring screen over the keyguard (biometric lock on),
  minute repeats of full_long do not re-alert/flash, and the Alarms settings
  tile shows Granted/Not granted with a working Grant button on Android 14+.
- Native notification Dismiss does not run Dart, so the next habit occurrence
  is scheduled on the next app open (no headless alarm-window rebuild yet).
- Google sign-in + runtime permissions: verify sign-in on Android (debug +
  release), decline path, device-calendar import/settings, first reminder save
  / alarm test prompts, exact-alarm/full-screen prompts for clock/lock-screen
  presets. Google Cloud console owner steps still required (SHA-1 entries,
  Calendar/Tasks APIs, Web `serverClientId` match).
- Microsoft web sign-in: `app/web/auth.html` added; Entra SPA redirect
  registration for `http://localhost:8080/auth.html` still required (owner
  console). Android remains primary verification target.
- Full `flutter test` (test/all_test.dart) ran here on 2026-11-11: 504 tests
  passed; `flutter build apk --debug` also succeeded after the alarm
  hardening changes. Device-only alarm behavior still needs owner verification.
- Device profile run for startup/calendar rebuild timings still useful.
- Samsung SM A556E widget verification was interrupted by USB disconnect.

## Code follow-ups

- Split files >300 lines and functions >50 lines (U10): `event_editor_sheet.dart`, `task_editor_sheet.dart`, `event_details_sheet.dart`, `app_shell.dart`, `tasks_screen.dart`, `note_editor_screen.dart`, `habit_editor_sheet.dart`, `habits_screen.dart`, and `event_repository.dart`/`occurrence_repository.dart` are now safely re-split/merged (part/mixin structure, API preserved). `task_repository`, `sync_engine`, `home_widget_data_binder`, and `focus_screen` were already split. Repo-wide recheck for remaining >300-line non-generated files is in progress (step 2).
- Microsoft remote deletions: event and calendar remote deletions still not
  reconciled (calendar view is time-windowed). Task list/task deletions are
  reconciled conservatively on successful full-scope/list fetches.
- Projected task occurrence completion: uncompleting a suppressed projected
  occurrence has no calendar-surface undo yet (`TaskRepository.uncompleteTaskOccurrence` exists).
- Week widget: Motorola One Fusion filled a 4x2 cell (dark 3-day range) and setup
  dialog persisted theme/day count; recheck after device verification.
- Migration tests: full step-by-step Drift schema snapshot replay is not set up
  (v4->v5 and v7/v11 regressions are covered).

### Deferred hardening (2026-11-09)

- Markdown preview: indented code blocks are not excluded from the soft-newline hard-break preprocessing, so their rendered lines gain two trailing spaces (content otherwise preserved); unusual nested/longer fenced code blocks can escape the render-only fence tracker. Add tests and tighten the tracker if needed.
- Event descriptions: after a recurring series split, the old master can keep a stale notesOverflowNoteId pointing at the same canonical note; reverse sync uses limit(1) and may update only one event. Clean the split path or document the shared-link behavior.
- Event descriptions: saving a description can write Events.notes and enqueue an event update twice (editOccurrence then reverse sync), and ensureOverflowNote/setNotesOverflow are now unused in lib/. Consider removing the redundant write and dead helpers.

## UX / behavior gaps

- Task-list and smart-list chip long-press management has no widget test.
- Habit agenda rows and "Open habits" navigation covered by repository/static
  checks only (month/timeline markers and tap action sheet have widget tests).
- Long-press drag reorder has no dedicated widget test (`docs/TASK_DATES_AND_SORTING.md`).
- CalendarScreen 2 s session-restore fallback can trigger one duplicate initial
  build if settings loading stalls longer than 2 s.
- Matrix AsyncNotifier fallback can briefly render Auto on cold start before a
  saved Priority mode arrives.
- Timeline/agenda rows do not show account/calendar source labels (task tiles,
  task details, event details do); adding without per-row queries needs source
  columns in occurrence cache.
- Matrix and task-editor layout tests cover 320 dp at default text scale; very
  large accessibility text scaling is not covered.
- Recurring Google series cannot move between Google accounts (Google has no
  single-token cross-account move); moving such a series to a local calendar is
  supported. Cross-account copy/delete requires both accounts synced at least
  once; if the source account is removed before its delete op runs, the old
  remote row can remain.
- Task subtasks keep their own list/source when a parent task is moved; moving
  a whole subtask tree is not automatic.

## iOS (owner / macOS + Xcode)

- Home-screen widgets not implemented: requires WidgetKit extension target, App
  Group entitlement, signing, and SwiftUI views mirroring Android providers
  (`docs/IOS_WIDGETS.md`). Do not fabricate Xcode project integration on Linux.
- Critical Alerts owner steps: select `Runner.entitlements` under Signing and
  Capabilities, add `requestCriticalAlerts` handler on `ephemeron/alarms`
  (`UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .criticalAlert])`), request entitlement in App Store Connect.

## Phase 10 / release (owner)

- Security review code-level done (`docs/SECURITY_REVIEW.md`); Play declaration,
  backup rules, release-build verification are owner checks.
- Privacy policy draft done (`docs/PRIVACY.md` EN/PT); needs lawyer sign-off.
- Store assets, staged rollout: owner.

## Dependencies / build

- `wakelock_plus` left at 1.8.0 (1.8.2 unreachable: conflict with
  `battery_plus` 7.1.2 via `dbus`). Revisit when either package relaxes.
- Deferred: AGP 9.3 + Gradle 9.5 upgrade (needs migration and build
  size/behavior comparison).
- Do not run a release build while `flutter run` is active (both rewrite
  `GeneratedPluginRegistrant.java`; debug registrant includes `integration_test`
  and release Java compile fails).

## UX overhaul follow-ups (2026-11-11)

- Device/visual verification is pending because the workstation screen was
  locked during implementation: verify light/dark/AMOLED theme, More command
  center, onboarding, quick add, search, calendar, tasks, notes/auth,
  habits/focus/countdowns, and alarm ring navigation on a real device.
- Localization pass: the UX overhaul added English strings for the More sheet
  create/search labels, quick-add hints and chips, search empty/no-results/tag
  sheet, notes search/status retry, countdown labels, focus custom-duration
  dialog and stats, and alarm ring source/auto-snooze text. Add ARB keys or
  intentionally document English-only.
- Accessibility: habit row icon buttons are about 34x36 at 320dp, below the
  48dp guideline; revisit the dense-row layout with an accessible alternative.
- Search: tag task limit is duplicated (50) between the UI footer and the
  repository default; keep a single source of truth. If one group errors while
  another group has rows, the failed group is not surfaced.
- Notes: the relative "Saved Xm ago" label refreshes on editor rebuild rather
  than a live timer; accepted to avoid periodic wakeups.
- Alarms: permission-tile FutureBuilder futures are recreated on parent
  rebuild; hoist/cache them if the status flash is observed on device. Ring
  Done/+1 haptics fire before the action resolves.
- Security/visual: the biometric app lock screen still uses a default Material
  theme instead of the app theme. Any styling change there is security-adjacent
  and needs owner-approved, logic-preserving work.
- Logging hygiene: pre-existing debugPrint calls remain in
  features/auth/data/google_auth/*; remove them in a dedicated privacy cleanup
  after verifying no token or personal data is logged.
- Full test suite passes (557 tests) and flutter analyze is clean after the UX
  merges; test/all_test.dart must be regenerated with
  `dart run tools/gen_test_runner.dart` whenever a case file is added.

## Next priorities (2026-11-12)

- Google single-occurrence push: exception rows are not serialized or queued to
  Google yet, so "this event only" edits/deletes stay local. An unmerged local
  branch explored partial field and read-only fixes, but it was rejected in
  review.
- Single-occurrence integrity: timed series alerts still use master reminders,
  the details edit can target the first occurrence, and location/Meet
  inheritance on moved exceptions is incomplete.
- Read-only shared calendars: hide the details move action and block timeline
  drag/save when the source calendar is read-only; enforce source read-only at
  the repository boundary.
- Sync diagnostics: failed outbox rows and per-calendar errors are invisible.
  Transport errors no longer abort sync, but a pending/failed changes view with
  retry/discard is still missing.
- Device-calendar live sync: replace the one-shot import with stable device
  event ids and conservative upsert/reconcile.
- Creation gestures: timeline tap/drag creation is done; the all-day strip and
  month view still lack quick-create affordances.
