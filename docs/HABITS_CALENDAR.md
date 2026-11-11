# Habits on the calendar

## Problem

Habits were only visible on the Habits screen. Users could not see which habits
were scheduled for a given day while planning in the calendar, and logging a
habit required leaving the calendar. This change surfaces scheduled habits in the
timeline, month grid, and agenda, and makes logging a single tap.

## Schedule rules

`isHabitScheduled(HabitSpec spec, DateTime day)` in
`app/lib/domain/habits/streaks.dart` is the single scheduling predicate.

- `daily`: every day.
- `weekdays`: the day's weekday bit is set in `weekdaysMask` (Monday is bit 0).
- `interval`: every `intervalDays` days counted from `startDate`. If
  `intervalDays` is missing or below 1, the habit behaves as daily.
- `weekly`: available every day so the user can log any day toward the weekly
  target.
- All frequencies hide days before `startDate` when it is set.

Streaks use the same predicate, so the calendar and streak engine cannot drift
apart.

## Streak grace for today

`currentStreak` keeps the run that ended yesterday when today is scheduled and
has no done or skipped log yet. Today only counts as missed after it has passed
without a log; until then the streak is not zeroed, so opening the app in the
morning does not show a broken streak. Any scheduled day before today that is
neither done nor skipped still breaks the streak. Skipped days remain neutral
and done days extend the run. Weekly-target habits keep their own in-progress
week grace.

## Timed and all-day placement

A habit with a reminder time appears as a timed block; a habit without one stays
in the all-day strip.

- The reminder time is stored as `HH:mm` in `Habits.reminderTime`. It is parsed
  into local minutes since midnight on `HabitCalendarEntry.timeMinutes`.
- Timed habits render in the hourly grid at their reminder time with a fixed 30
  minute height. The block shows the name, check/dash state, and compact goal
  progress when the habit has a goal.
- Untimed habits remain in `TimelineAllDayStrip`, which caps visible rows and
  shows the `+N habits` overflow count.
- Invalid or empty reminder values fall back to the all-day strip instead of
  crashing.
- Month and agenda surfaces keep showing every scheduled habit, timed or not.

## Marker behavior

`HabitCalendarMarker` is the shared compact widget used by the all-day strip,
month grid, selected-day list, and agenda.

- Tap or long-press opens the shared habit action sheet.
- The marker no longer toggles done directly. Logging actions live in the sheet.
- Month habit markers occupy the same per-day slots as events. Events and
  habits are combined before slot calculation, so the `+N more` count stays
  correct and the cell cannot overflow.
- Agenda and month selected-day list: habit rows appear above events for each
  day. A day with only habits is not treated as empty.

## Action sheet

`showHabitActionSheet` in
`app/lib/features/calendar/presentation/habit_action_sheet.dart` is used by
timed blocks, all-day markers, month markers, and agenda rows.

The header shows the habit name, day, reminder time when present, and a goal
progress bar when the habit has a positive goal. Actions:

- `Mark as concluded`: sets done for the day. When the log is already done the
  action becomes `Mark as not concluded` and clears done. Unmarking resets the
  day's amount to 0 while keeping any skipped flag.
- `Add <increment> <unit>`: adds `increment ?? 1` to the day's amount through
  `HabitRepository.addAmount`. The unit is included in the label when present.
- `Subtract <increment> <unit>`: shown when the habit has a positive goal.
  Removes `increment ?? 1` through `HabitRepository.subtractAmount`, clamping
  at 0. The unit is included in the label when present.
- `Skip for today` / `Unskip for today`: toggles the skipped flag.
- `Open habits`: pops the sheet and navigates to the Habits tab (`/tab3`).

The sheet watches the existing habit-log stream so progress, done, and skipped
states update in place after each action.

## Goal increments

`HabitRepository.addAmount(habitId, dayKey, amount)`:

- Creates the log when missing and increments `HabitLogs.amount` when present.
- Preserves the existing done and skipped flags.
- Marks the log done when a positive `goalAmount` is reached.
- Enqueues the habit-log outbox update and touches the habit so sync picks it up.
- `backfill` and `setSkipped` enqueue the same habit-log update.

`HabitRepository.subtractAmount(habitId, dayKey, amount)` is the decrement
counterpart:

- Does nothing when no log exists, so a decrement never creates a zero or
  negative row.
- Ignores zero and negative amounts.
- Subtracts `amount`, clamping the result at 0.
- Clears done when a positive goal is no longer reached and sets done when the
  remaining amount still reaches it.
- Preserves skipped and enqueues the same habit-log update as `addAmount`.

`setDone(habitId, dayKey, false)` writes amount 0, keeps done false, preserves
skipped, and does not cancel scheduled alarms.

## Habits list selection and bulk actions

- Long-pressing a habit row enters selection mode and selects that row.
- While selecting, tapping a row toggles its selection instead of opening the
  editor, the row's trailing controls are hidden, and the floating add button is
  hidden.
- The app bar in selection mode shows a close button, `<n> selected`, and bulk
  archive/unarchive and delete actions.
- Bulk archive archives every selected habit, or unarchives all when every
  selected habit is already archived. Rows already in the target state are
  skipped.
- Bulk delete asks for confirmation with the selected count before scheduling.
- Both actions use the durable 6 s undo buffer: one SnackBar per action with
  Undo cancelling every scheduled operation, then the selection clears.
- Selection is pruned when rows leave the active archived/unarchived list, and
  bulk actions resolve the live selected rows at action time.
- Back navigation while selecting clears the selection instead of leaving the
  screen. Nothing is hard deleted.

## Layout and performance

- `HabitRepository.watchCalendarEntries(fromKey, toKey)` is one reactive Drift
  query over the requested date-key range. It reads `habits` and `habit_logs`,
  generates the day range in SQL, and filters scheduling in Dart, so there is no
  per-day N+1 query. The query now also returns reminder time, unit, goal
  amount, increment, and the current log amount.
- `calendarHabitEntriesProvider` keys that stream to the existing calendar cache
  range, so timeline, month, and agenda share one subscription.
- `timelinePlacementsFor` lays out events and timed habits together per day. The
  existing lane/overlap algorithm handles side-by-side and nested blocks. Habit
  layout keys use a `habit:<id>@<day>` prefix so they never collide with event
  occurrence row ids. Habit blocks cannot become parents of events, so a short
  habit never hides an overlapping event inside its own container.
- No schema change, no new package, no timers, no background polling, and no
  change to battery behavior.

## Compatibility

- Calendar habit data is read-only from existing tables; no columns or
  migrations change.
- Archived and soft-deleted habits are excluded.
- Widgets degrade to no markers when the habit stream is loading or empty.
- Works on all supported platforms because it uses the same Drift and Flutter
  widgets as the rest of the calendar.

## Verification

- Domain scheduling cases: daily, weekdays, interval anchored on the start date,
  future start-date exclusion, weekly availability.
- Repository cases: range stream shape, timed metadata, amount increments and
  goal completion, done/skip preservation, decrement clamping/no-op, unmark
  reset, skip/backfill outbox updates, archive exclusion, and toggle behavior.
- Habits screen cases: minus control decrement, long-press selection mode,
  stale-selection pruning, live-row bulk archive, and confirmed bulk delete
  scheduling.
- Timeline cases: timed habits render in the hour grid at the reminder time;
  untimed habits stay in the all-day strip; overlap layout keeps habit and event
  keys distinct.
- Widget case: tapping a month habit marker opens the action sheet and
  `Mark as concluded` writes a done log for the day.
- `dart format` on changed files, `flutter analyze`, and `flutter test`.
