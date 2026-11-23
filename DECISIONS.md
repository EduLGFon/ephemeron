# Decisions
Migrated from `docs/decisions.md`.
## D01 - Cancelled exception rows as EXDATE
Decision: cancelled exception rows act as EXDATE; no separate column. Reason: simpler schema.
## D02 - Root .gitignore bare test rule
Decision: root .gitignore bare `test` rule ignores new test files; force-add them. Reason: avoid committing test artifacts accidentally.
## D03 - Image compression without WebP
Decision: re-encode to JPG q80 (opaque) or resized PNG (alpha) at max 1600 px; files under 200 KB skip. Reason: image 4.3.0 has no WebP encoder.
## D04 - Native alarm package namespace
Decision: alarm classes live under com.spotnik.ephemeron. Reason: receivers never fired under com.example.ephemeron.
## D05 - Alarm snooze gentle default preset
Decision: snooze keeps gentle default preset; per-alarm preset not persisted in alarms_index.
## D06 - Snoozed alarm state
Decision: snoozed alarms use state `snoozed`; pending queries include `scheduled` and `snoozed`; rebuilds preserve snoozed rows and request codes until fire or resolve.
## D07 - Meet join via system channel
Decision: Meet join uses ephemeron/system channel (ACTION_VIEW) instead of url_launcher; unsupported platforms copy-link.
## D08 - Dropped device/SDK-dependent tests
Date: 2026-10-30
Decision: dropped physical-device alarm matrix, 60 fps bench, 24 h battery bench, APK/AAB size audit, 3-day soak, MediaPlayer sound, flashlight blink. Reason: owner instruction; no devices/SDK.
## D09 - Widget test DB close before final pump
Decision: close in-memory Drift DB and unmount in test body before final pump. Reason: teardown close runs too late.
## D10 - Session restore lightweight UI state
Decision: lightweight UI state in SharedPreferences; form contents in Drift drafts, autosaved 500 ms. Markers set on open, cleared on dispose; drafts expire after 7 days. Notes need no draft row.
## D11 - Google sync account linking
Date: 2026-11-03
Decision: sign-in requests Calendar + Tasks scopes; 401/permission-403 keeps row with backoff and raises reconnect banner; events/tasks gain googleAccount (schema v9). Reason: Android tasks never synced under Calendar-only scope.
## D12 - Google silent restore
Date: 2026-11-13
Decision: startup restore never calls attemptLightweightAuthentication; reuse stored tokens and call clientAuthorizationTokensForScopes with prompting disabled. Interactive sign-in persists user id. Reason: avoid account picker on every launch.
## D13 - Full-screen alarms keep Flutter RingScreen
Decision: keep Flutter RingScreen; native activity may replace later.
## D14 - Biometric exemption for ring screen
Decision: ring screen bypasses _LockGate only when activeRingRequestProvider set from a verified `fired` row. Reason: native intents never bypass gate.
## D15 - Alarm fire marks row before posting
Decision: mark row `fired` or `missed` before posting; notifications use setOnlyAlertOnce. Reason: full-screen tap reads settled state; no re-alert from updates.
## D16 - full_long minute repeats restart service
Decision: repeats restart AlarmRingService without new notification; first fire only notifies; phase extra carried through re-posts.
## D17 - Occurrence cache source labels (schema v14)
Decision: source_label/source_account filled at rebuild time; pre-upgrade rows keep null until next rebuild; surfaces hide empty labels.
## D18 - Shared calendar claims election
Decision: one owner/reader election per shared calendar; shared pull fails closed when account list unknown; stale reader keys removed only when provably stale.
## D19 - Sync diagnostics allowlisted labels
Decision: Sync issues renders only allowlisted operation/entity/error labels plus counts and ages; no payloads, tokens, emails, titles, bodies.
## D20 - Microsoft remote deletions
Decision: soft-delete calendars absent from complete /me/calendars only when owned, clean, remote-backed; events reconciled only inside fully fetched window; Graph paginator throws on partial listing.
## D21 - Read-only calendars enforced at repository
Decision: read-only enforced at repository boundary for create/move/edit/delete/attendee/RSVP; moving exception resolves to master.
## D22 - Single-occurrence integrity
Decision: exception uses own reminders/preset when set else inherits master's; edit/delete target exact occurrence; new exception inherits master fields when not overridden.
## D23 - Calendar quick create
Decision: all-day strip always rendered with 32dp minimum empty-day target; month cells create 09:00 timed event on long-press; gesture intent wins over autosaved draft.
## D24 - Device calendars manual import/refresh
Decision: user-initiated import/refresh with fixed [now-30d, now+365d] window; no background live sync; prune mappings only for visible deselected calendars.
## D25 - Localization English-only
Decision: UI stays English-only; intl formatting and existing ARB keys only; full localization is separate owner-approved effort.
## D26 - Startup state coalescing
Decision: calendar rebuild fallback and session restore coalesce into one scheduled build; matrix board waits for saved mode; task-chip tooltip uses manual trigger mode.
## D27 - File-size review thresholds
Decision: cohesive 300-400 line modules retained; earlier outliers split into part files under 300 lines.
## D28 - Material/Cupertino migration (Flutter 3.50)
Date: 2026-11-13
Decision: all app/test imports use material_ui/cupertino_ui; app code uses GlobalMaterialLocalizations.delegates from material_ui. Reason: Flutter 3.50 deprecates material/cupertino packages and legacy delegates.
## D29 - Generated l10n header workaround
Date: 2026-11-13
Decision: app/l10n.yaml sets header ignore for deprecated_member_use in generated files only. Reason: gen-l10n still emits legacy delegates.
## D30 - Android toolchain versions
Date: 2026-11-13
Decision: AGP 9.5.1, Gradle 9.9.1, Kotlin 2.4.21; Android.newDsl=false and builtInKotlin=false unchanged. Reason: latest stable, build-verified.
## D31 - sqlite3 direct dev dependency
Decision: sqlite3 listed as direct dev dependency because tests import it.
## D32 - home_widget pixelRatio
Decision: all four renderFlutterWidget calls pass explicit pixelRatio (2/1/2/2). Reason: home_widget 0.10 changed default to 0.8.
## D33 - Postgres image pin
Decision: Postgres pinned to postgres:18.7-alpine. Reason: patch within 18.x, no volume migration.
## D34 - Dockerfile warm-up bare specifiers
Decision: warm-up imports bare specifiers through deno.json. Reason: avoid drift from pinned deps.
## D35 - wakelock_plus held at 1.8.0
Decision: wakelock_plus stays 1.8.0. Reason: 1.8.2 needs dbus ^0.8.0 while battery_plus pins dbus ^0.7.0.
## D36 - Alarm wake reconciliation
Date: 2026-11-16
Decision: app open/resume marks overdue scheduled/snoozed rows missed and cancels native registrations; stale fired rows older than 2 min become missed unless active ring; missed rows retained 24 h.
## D37 - Alarm ring containment
Date: 2026-11-16
Decision: full-screen audio starts only after RingScreen first frame via startRing channel; deliveries older than 2 min or without trustworthy fire time become missed; leaving without action auto-snoozes 10 min.
## D38 - Google token recovery
Date: 2026-11-16
Decision: storing account independent of token; transient failures keep account; 401 clears access token and retries once silently; 403 is definitive; startup never interactive.
## D39 - Linked countdowns (schema v15)
Date: 2026-11-16
Decision: countdowns gain linked_type/linked_id plus index; links local-only for event/task/habit; date edits keep target dates in step; backup restore normalizes links.
## D40 - Habit compliance statistics
Date: 2026-11-16
Decision: stats use local logs; goal habits scored by weighted amount/goal over scheduled past days; partial credit, skipped neutral, future excluded, capped 100%.
## D41 - Matrix density and lateness
Date: 2026-11-16
Decision: matrix rows natural height; open tasks due before today render title in colorScheme.error; timeline titles wrap to block height with source label only if space allows.
## D42 - UI rebirth design system
Date: 2026-11-18
Decision: new design system under core/design; adaptive shell; Stream opt-in via settings.streamEnabled; additive SharedPreferences keys only; no Drift schema change.
