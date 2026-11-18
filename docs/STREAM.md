# The Stream (v3) UI - Status

## What it is

A new time-centric "Stream" UI. Stream is the default UI; `/` redirects to
today's day view.

- Route: `/stream/<yyyy-MM-dd>/<zoom>` (zoom is `day`/`week`/`month`/...),
  registered in `app/lib/app/router/app_router.dart`. `/` redirects to today's
  day view.
- Legacy `/tab0`..`/tab6` shell routes remain live for launcher, alarms,
  widgets and session restore.

## What exists and is merged on v3

- Design tokens/themes: `app/lib/features/stream/design/` (tokens, palette,
  theme, theme mode with light/dark/true-black/system + persisted mode) and
  `application/stream_theme_provider.dart`, `stream_theme_preferences.dart`.
- Time viewport: `engine/stream_time_viewport.dart`, `engine/time_viewport.dart`,
  `engine/stream_mark_layout.dart`, `engine/mark_culler.dart`.
- Day canvas + gesture region: `presentation/day/` (day_canvas, painter, style,
  day_gestures).
- Chrome: `presentation/chrome/` (now_line, time_rail, breadcrumb, scrubber).
- Day mark mapper/providers: `application/stream_day_mark.dart`,
  `stream_mark_mapper.dart`, `stream_day_providers.dart`; `data/fake_marks.dart`.
- Capture parser (pure, pt/en, 50+ table cases): `capture/` (capture_parser*).
- Capture bar + preview chips: `presentation/capture/`.
- Command palette + parser + fuzzy matcher: `presentation/commands/`.
- Tray strip + panel: `presentation/tray/`.
- Slipped trail + triage: `presentation/slipped/`.
- Peek inline editor: `presentation/peek/`.
- Agenda lens: `presentation/agenda/`.
- Focus timer + band: `presentation/focus/`.
- Countdown landmarks + edge chips: `presentation/countdowns/`.
- Habit gutter + streak line: `presentation/habits/`.
- Gesture school overlay: `presentation/school/`.
- Designed states (empty/error/offline/skeleton): `presentation/states/`.
- Platform capabilities + feedback adapter: `presentation/platform/`.
- Week + month + year level views: render through `StreamLevelHost` on the
  day surface (viewport/canvas).
- Day surface shell: centered Now line, rail, scrubber, Now pill, header, route
  (`presentation/stream_placeholder_screen.dart`, `stream_route_params.dart`).

## Not yet wired into the surface

Component units with tests; items marked (wired) are now mounted on the day
surface, the rest are not yet mounted:

- capture bar (wired)
- command palette (wired)
- tray drag-to-schedule
- peek inline editor
- slipped triage
- agenda toggle (wired)
- gesture school (wired)
- focus mode controls
- habit gutter
- countdown landmarks
- week/month level switching (wired)
- year level (wired)
- settings sheet (wired)
- progressive hints
- permission banners
- old UI removal

## Verification status

Every component unit passes its targeted tests and `flutter analyze`. The merged
tree has not passed a full-suite checkpoint under load. Phase 0 performance
budgets (frame build/raster, cold start, memory, 2000-mark scroll) are UNMEASURED
after the spike fix; do not claim otherwise.

## Data-model gaps (suggested only, no schema change)

- Task time-block/duration is derived from `plannedStart`/`plannedEnd`, not a
  first-class field.
- Countdown `targetDate` is nullable (`app/lib/data/drift/tables/misc.dart`).
- Focus sessions have no range `StreamProvider`; range query is a `Future`
  (`sessionsInRange`).
- There is no existing app-level `ThemeMode`; the Stream adds its own persisted
  mode (`stream_theme_mode.dart`).
- Habit time-of-day exists as `timeMinutes` (nullable int).
- Notes are plain text in the editor.

## How to run and verify

- Run: `flutter run` (from `app/`).
- Targeted: `flutter test test/cases/<file>_case.dart`.
- Codegen: `dart run tools/gen_test_runner.dart`, `flutter gen-l10n`.
- Analyze: `flutter analyze`.
- Tests: `flutter test` (serial; concurrent runs contend on the tool lock).
