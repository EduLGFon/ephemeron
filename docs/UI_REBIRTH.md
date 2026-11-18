# UI rebirth (2026-11-18)

Presentation-layer replacement for Ephemeron: premium, fast and battery-light
UI on every primary screen, with the existing data, domain, sync and
repository layers preserved. No Drift schema or migration change; only the
approved additive SharedPreferences keys were added.

## Goal

Replace the old tab shell and screen chrome with one design system, an adaptive
shell and a local-first Today home while keeping every existing feature:
Google/Microsoft sync, accounts, alarms and ring screen, home widgets, notes,
matrix, smart lists, tags, subtasks, trash, calendar scopes/RSVP/source moves,
habit/focus stats, countdowns, onboarding, backup/restore, search, biometric
lock, power saving, navigation order and localization scaffolding.

Owner decisions (2026-11-18): primary destinations Today, Tasks, Calendar,
Habits and Focus; secondary Countdowns, Notes, Matrix, Stream and Settings;
Countdowns also appear as a Today section with a "See all" page; Stream is
opt-in (default off) and keeps every feature.

## Design system

Shared presentation code lives in `app/lib/core/design/`.

- `tokens.dart`: `DsSpace` (4/8/12/16/24/32/48), `DsRadius` (8/12/16/24/pill),
  `DsBreakpoints` (compact 600, expanded 840, content max 1100), `DsMotion`
  (120/180/240 ms plus standard/emphasized curves), `DsIcon` (18/22/28),
  `DsSurfaces` (warm neutral light/dark, true-black AMOLED), hairline borders
  and ten precomputed category colours with light/dark fill and foreground
  pairs that pass contrast. Category colour is decorative identity, never the
  only status signal.
- `typography.dart`: `DsType` builds the Inter text theme; display/headline
  styles use the bundled Fraunces subset. `DsType.numeric` applies tabular
  figures to clocks, counters and tables. Fonts are bundled under
  `app/assets/fonts/`; there is no runtime font fetch.
- `theme.dart`: `EphemeronTheme.build(mode, platformBrightness, accent,
  background, dynamicColor, dynamicAccent, compact)`. Modes are
  `light|dark|amoled|system`, AMOLED is true black, and the default accent is
  Ember `#C2410C`. Material 3 `ColorScheme.fromSeed` with hand-tuned flat
  surfaces, 1px hairline borders and no elevation.
- `layout.dart`: `AppLayout` and `AppLayoutScope`; the shell decides the layout
  once and screens never re-measure the shell breakpoint.
- `components/`: `AppPage`, `AppSurface`, buttons, fields, chips, headers,
  empty/error/skeleton states, sheet/dialog helpers, `AppSyncIndicator`,
  presentational task/event/habit/countdown rows, progress ring, heatmap and
  checkmark. Screens import component files directly; there is no barrel file.

Performance rules applied throughout:

- Flat tonal surfaces and 1px hairline borders; no blur, BackdropFilter,
  glassmorphism, ShaderMask, opacity-animated subtrees, large shadows or
  clipped large subtrees.
- `ListView.builder`/slivers with stable `ValueKey(id)`; no nested scrollables
  or per-frame whole-screen rebuilds.
- Narrow provider slices with `select`/family; a row change does not rebuild
  the list. Today filters tasks once per emission instead of per row.
- Timer digits, rings, heatmaps and independently animating pieces sit inside
  `RepaintBoundary`; focus digits are driven by a 1s `ValueNotifier` only while
  a session runs. Today uses one minute-aligned timer for relative labels.
- Numeric text uses tabular figures. Animations are 120-250 ms,
  transform/opacity only, and honour reduced motion through `AppMotion` /
  `MediaQuery.disableAnimations`.
- Custom visuals (rings, heatmap, empty art, checkmark) are `CustomPainter` or
  plain shapes. No image assets, Lottie or network fonts.

## Adaptive navigation and destinations

Destinations and paths (`app/lib/app/shell/destinations.dart`):

- Primary: 0 `/today`, 1 `/tasks`, 2 `/calendar`, 3 `/habits`, 4 `/focus`.
- Secondary: 5 `/countdowns`, 6 `/notes`, 7 `/matrix`, 8 `/stream/:date/:zoom`.
- Settings, search and alarm settings stay top-level pushed routes; `/ring` and
  the widget/ring cold-start logic are preserved.

`AdaptiveShell` decides the layout once with one `LayoutBuilder`:

- Compact `<600dp`: bottom `NavigationBar` with the five primary destinations
  in persisted `settings.navOrderV2` order, a More action and a thumb-reachable
  main Quick Add FAB.
- Medium `600-839dp`: `NavigationRail` with the primary destinations, More and
  Settings.
- Expanded `>=840dp`: labelled 240dp sidebar with a brand/date block, primary
  and secondary destinations, Settings at the footer, and content capped at
  1100dp and centered.
- The More sheet contains search, create actions, secondary destinations,
  Stream only when enabled, Settings and primary-destination reorder. Shortcuts
  are N, `/` and Ctrl/Cmd+K, Esc, digits 1-5, T, and calendar arrows while not
  editing text.
- Legacy `/tab0..7` routes map to the new paths, `/widget*` opens Calendar, `/`
  opens Today, and session restore migrates `session.navVersion <2` without
  opening a disabled Stream.

## Screen inventory

Rebuilt with the new design system:

- Today: header, sync indicator, Now/Next hero (active focus, current or next
  event), habits strip, unified agenda with overdue section, countdown cards,
  calm empty day and two-column expanded body.
- Tasks: list/smart-list chips, filter modes, `AppTaskRow` priority/overdue
  treatment, search, sort, list management, trash, swipe complete/reschedule,
  drag reorder only for custom sort without search.
- Calendar: header and period subtitle, day/week/month/agenda/year views, view
  menu, today/prev/next, now line, sync/offline/error banners, empty slots and
  preserved source-move and RSVP flows.
- Habits: week strip, sections, habit rows with one-tap toggle, skip, streaks,
  week dots, selection/bulk actions, timer control and heatmap/stats links.
- Focus: tabular timer digits in a `RepaintBoundary`, progress ring,
  start/pause/stop, presets and breaks, task/habit linking, today total,
  history, stats/CSV and alarm/wakelock behaviour.
- Countdowns: grid/list cards, upcoming/passed/no-date groups, editor and undo.
- Notes: folders/breadcrumbs, grid/list toggle, search, empty/error states,
  editor and Markdown preview unchanged.
- Matrix: responsive 2x2, Auto/Priority modes, tray, drag/drop, add task.
- Search: header, search field, result groups, snippets, tag sheet, history and
  localized title.
- Settings and onboarding: grouped account/sync, notifications, appearance,
  time, shortcuts, Stream opt-in, data, security, navigation and about; three
  skippable onboarding pages.
- Quick Add: mobile sheet / desktop dialog, one autofocused field, type and
  date chips, list/priority chips, live parse preview, Enter submit, add
  another and preserved draft restore.
- Shell and More: adaptive navigation, reorder, Stream entry gating, sheets and
  desktop shortcuts.

Existing editors and flows that were not rebuilt (event/task/habit/countdown
editors, note editor/Markdown, auth, alarm settings and ring) keep working and
use the new shared components where already migrated.

## Data and derived providers

- `features/today/application/today_providers.dart`: `todayTasksProvider`
  derives today and overdue buckets from `openTasksProvider(null)` once per
  emission; `todayOccurrencesProvider` uses the calendar cache coordinator;
  `todayHabitEntriesProvider` uses scheduled habit entries for the local day;
  `todayCountdownsProvider` and the existing countdown math drive compact cards;
  the active focus session and `combinedSyncStatusProvider` feed the hero and
  sync indicator.
- `calendarCacheCoordinatorProvider` keeps range rebuilds single-flight and
  rebuilds only when the requested range is not already covered; Today and
  Calendar invalidate it when `occurrenceDirtyProvider` turns true.
- Screens watch the narrowest provider slice; lists are driven by Drift streams
  and never by network responses. Local data never shows a spinner; remote-only
  work uses skeletons and errors offer retry by provider invalidation.

## Stream opt-in

- `settings.streamEnabled` is additive and defaults to `false`.
- When off, Stream is absent from More and the sidebar, direct `/stream/...`
  redirects to `/today`, legacy `/tab7` maps to Today and session restore never
  opens the Stream branch.
- When on, Stream stays the full existing v3 surface at branch 8 and is reachable
  from More/sidebar. No Stream component or feature was removed.

## Optimistic updates and undo

All writes remain optimistic: the local Drift write updates the UI immediately
and the outbox/sync engine reconciles in the background. The existing 6s undo
buffer (`pendingOperationsProvider`) and `showUndoSnackBar` are preserved for
destructive actions; irreversible actions keep confirm dialogs, and no user
data is hard-deleted.

## Accessibility

- WCAG AA contrast through the tonal schemes; category colours pair with text
  or shape and are never the only signal.
- 48dp touch targets on touch platforms, Semantics labels for icon-only
  controls, visible focus rings and logical focus order.
- Text scaling to 200% and 320dp layouts are covered by widget tests for the
  components and primary screens; app-wide visual passes on a device remain
  owner checks.
- Reduce motion is honoured (MediaQuery and the persisted setting), and dates,
  times and numbers use `intl`/`DeviceDateFormat` with the 12/24h preference.

## Verification

Commands run from `app/` in this worktree on 2026-11-18:

- `flutter pub get` - exit 0 (no new packages; dependencies unchanged).
- `dart run tools/gen_test_runner.dart` - exit 0, 212 case files, guard test
  present. The generator output is formatted with `dart format` before the
  format gate.
- `dart format --output=none --set-exit-if-changed lib test` - exit 0, 868
  files, 0 changed.
- `flutter analyze` - exit 0, "No issues found!".
- `flutter test` (single generated entrypoint, serial) - the first run had
  1821 passed and 3 order-dependent failures (`habits_timer 320dp trailing no
  overflow with timer`, `l10n search screen localizes titles`, `todo_coverage
  drag handle reorders tasks and persists sortOrder`). Each failed test passed
  alone and the immediate full rerun passed: 1824 passed, 0 failed. These are
  recorded as flakes, not regressions.
- `flutter build web --release` - exit 0.
- `flutter build apk --release --target-platform android-arm64` - exit 0.

## Measured sizes

- Web: `build/web/main.dart.js` gzip = 1,901,457 B. Budget 2,097,152 B
  (2 MiB); previous baseline 1,761,101 B. Delta +140,356 B (+8.0%) and under
  budget.
- Android arm64 release APK: 29,594,116 B. Previous baseline 28,346,708 B.
  Delta +1,247,408 B (+4.4%). Build warnings about CupertinoIcons and three
  plugins applying the Kotlin Gradle Plugin are pre-existing and unrelated to
  the UI work.

## Unmeasured performance

No Android device or emulator is available in this environment. Frame
build/raster timings, cold/warm start, idle RAM, battery, long-list scroll and
120Hz behaviour were not measured; do not treat architecture.md budgets as
verified. Dynamic colour on Android 12+, notification/exact-alarm denied
states, the 320dp/200% visual pass and the alarm/ring flows remain device owner
checks. iOS, macOS and Windows builds were not run on this Linux host; Linux
desktop was also not built in this pass because it needs webkit2gtk-4.0.

## Assumptions

- The additive preference keys and 12/24h device formatting are the only
  behaviour changes; existing storage formats, routes for pushed screens and
  security/privacy claims are unchanged.
- Stream stays opt-in with all old features reachable; no data migration was
  needed.
- Widget tests are the evidence for 320dp/200% behaviour; they do not replace a
  device visual pass.

## Follow-ups

- Delete the unused `app/lib/app/shell/app_sections.dart` in an owning unit; it
  has no imports after the adaptive shell. The four legacy presentation files
  checked in this unit (`core/theme/app_theme.dart`, `core/theme/theme_tokens.dart`,
  `core/ui/empty_state.dart`, `core/ui/app_section_header.dart`) are still used
  and were kept.
- `tools/gen_test_runner.dart` emits import lines longer than the formatter
  limit; always run `dart format` after regeneration (the integration gate does).
- Stabilize the three order-dependent tests recorded above (habits_timer/l10n/
  todo_coverage) so the first combined run is green.
- Device checks listed in `docs/TODO.md`: profile frame timings, dynamic colour
  on Android 12+, denied notification/exact-alarm layouts, 320dp/200% visual
  pass, and iOS/macOS/Windows builds.
