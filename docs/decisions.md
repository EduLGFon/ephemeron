# Decisions

Decisions not covered by PLAN.md (lighter-weight option chosen by default).

- Cancelled exception rows act as EXDATE equivalents; no separate EXDATE column.
- Root `.gitignore` bare `test` rule ignores new test files; force-add them.
- image 4.3.0 has no WebP encoder, so attachment compression re-encodes to JPG q80 (opaque) or resized PNG (alpha) at max 1600 px; files under 200 KB skip re-encoding. No WebP, no version upgrade.
- Native alarm classes lived in `com.example.ephemeron` while the app namespace is `com.spotnik.ephemeron`, so receivers never fired and MainActivity could not resolve AlarmPlugin; moved to `com.spotnik.ephemeron`.
- Alarm snooze keeps the gentle default preset (per-alarm preset is not persisted in alarms_index).
- Snoozed alarms use state `snoozed` (Dart and native snooze paths, written after
  the schedule upsert); every pending-alarm query includes `scheduled` and
  `snoozed`, and window rebuilds preserve snoozed rows and request codes until
  they fire or are resolved.
- Meet join uses a tiny `ephemeron/system` channel (ACTION_VIEW) instead of a url_launcher dependency; unsupported platforms fall back to copy-link.
- Dropped without devices/SDK (owner instruction 2026-10-30): physical-device alarm matrix, 60 fps bench, 24 h battery bench, APK/AAB size audit, 3-day real-account soak, MediaPlayer-on-alarm-stream sound, flashlight blink.
- Widget tests: close in-memory Drift DB and unmount inside the test body
  before the final pump; otherwise Drift's stream-close zero-timer trips the
  pending-timer check (addTearDown close runs too late).
- Session restore (PLAN 8.1/8.2): lightweight UI state (tab, route, calendar
  anchor/view/dayCount, selected list/folder, search query/scope, focus
  options, open-sheet marker) in SharedPreferences for sync read at startup;
  form contents in the existing Drift `drafts` table, autosaved debounced at
  500 ms. No new dependency. Markers are set when a sheet opens and cleared
  in dispose (which process kill skips), so kills restore but normal closes
  do not; drafts expire after 7 days, reopen silently under 24 h and behind
  a "Restore draft?" banner above that. Notes need no draft row (they
  autosave to the DB).
- Google sync account linking (2026-11-03, Android tasks never synced):
  Calendar-only sign-in on Android meant Tasks calls 403d and the engine
  deleted the outbox rows as stale, then 401d on everything after expiry,
  all while the chip read synced. Fix: sign-in requests Calendar + Tasks
  everywhere (desktop already did); 401/permission-403 keeps the row with
  backoff and raises a reconnect banner instead of deleting; `events` and
  `tasks` gain `googleAccount` (schema v9, backfilled from parent
  calendar/list) so push/pull/discovery are scoped per account and one
  account's loop can no longer 404-drop another's rows.
- Full-screen alarms keep the existing Flutter RingScreen (no native alarm
  UI). A dedicated native activity may replace it later.
- Biometric exemption: the ring screen is shown without `_LockGate` only when
  `activeRingRequestProvider` was set from a verified alarms_index row in
  state `fired`. Native intents alone never bypass the gate; an unknown,
  scheduled, missed, or dismissed row is rejected silently.
- Alarm fire marks the row `fired` (or `missed` when notifications are off)
  before posting, so a full-screen tap always reads a settled state.
  Notifications use `setOnlyAlertOnce` so foreground-service updates and
  minute repeats cannot re-alert or flash.
- full_long minute repeats restart `AlarmRingService` without posting a new
  notification; only the first fire notifies. The `phase` extra is carried
  through service re-posts so focus next-phase actions survive.
- Occurrence cache source labels (schema v14): `occurrence_cache.source_label` and
  `source_account` are filled at rebuild time from the event calendar or task
  list using the shared source-label helpers. Rows created before the upgrade
  keep null labels until the next rebuild; timeline, agenda, and month surfaces
  hide empty labels and never query per row.
- Shared calendar claims: one owner/reader election per shared calendar. When the
  signed-in account list is unknown (`null`) the shared pull fails closed instead
  of pulling once per account. Stale `cal:reader:<remoteId>` keys are removed only
  when provably stale (owner signed in, calendar gone or disabled, or no live
  reader), and legacy `cal:<id>:token` rows are deleted once the
  `cal:v2:<id>:token` key exists.
- Sync diagnostics: the Sync issues screen renders only allowlisted
  operation/entity/error labels plus attempt counts and ages. Outbox payloads,
  syncState values/tokens, account emails, titles, and raw response bodies are
  never passed to the widgets. Discard is offered only after retries are
  exhausted; a read-only `SourceMoveException` discards the pending operation
  instead of retrying it forever.
- Microsoft remote deletions: calendars absent from a complete `/me/calendars`
  listing are soft-deleted only when owned by the account, clean, and
  remote-backed. Events are reconciled only inside a completely fetched
  `calendarView` window and only when clean, non-recurring, and with provable
  overlap. Tombstones revive when the remote row reappears. The Graph paginator
  throws instead of returning a partial listing at its page cap, so a partial
  listing can never trigger deletion.
- Read-only calendars: source read-only is enforced at the repository boundary
  for create, move, edit, delete, attendee, and RSVP operations, and mirrored in
  details, timeline, and editor UI. Moving an exception resolves to its master so
  a series never leaves an orphan exception in another calendar.
- Single-occurrence integrity: an exception uses its own reminders and alarm
  preset when set, otherwise inherits the master's. Details edit and delete
  target the exact occurrence, and a new exception inherits master
  location/Meet/visibility/transparency/reminders/preset/color when not
  overridden.
- Calendar quick create: the all-day strip is always rendered with a 32dp
  minimum empty-day target; month cells create a 09:00 timed event on long-press.
  Explicit all-day or time intent from the gesture wins over an autosaved draft.
- Device calendars stay a user-initiated import/refresh with a fixed
  `[now-30d, now+365d]` window; there is no background live sync (battery and API
  cost). Mappings are pruned only for visible calendars deselected in a completed
  import, keeping invisible and other-target mappings.
- Localization: the UI remains English-only by decision. `intl` is used for
  formatting and only the existing ARB keys are localized. A full localization
  pass is a separate owner-approved effort.
- Startup state: the calendar rebuild fallback and session restore coalesce into
  one scheduled build; the matrix board waits for the saved mode (Auto only after
  a real load error); the task-chip tooltip uses manual trigger mode so touch
  long-press reaches management while desktop hover still works.
- File-size review: after the two split passes, the modules that remain
  slightly above 300 lines (300-400 range, for example
  `device_calendar_import_service.dart`, `calendar_settings_screen.dart`,
  `sync_engine.dart`, `focus_screen_start.dart`) are cohesive
  single-responsibility files and were kept rather than split mechanically.
  `app_localizations.dart` follows the ARB source. The earlier outliers (570,
  568, 456, 435, 427, 422, 414, 413, 412) are now split into `part` files under
  300 lines.
