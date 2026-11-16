# Habits on the calendar

## Problem
Habits were only on Habits screen. Now scheduled habits surface in timeline, month grid, agenda; logging is one tap.

## Scheduling
`isHabitScheduled(HabitSpec, DateTime)` in app/lib/domain/habits/streaks.dart is the single predicate.
- daily: every day.
- weekdays: weekday bit set in weekdaysMask (Monday bit 0).
- interval: every intervalDays from startDate; missing/<1 behaves daily.
- weekly: available every day toward weekly target.
- All hide days before startDate when set.
Streaks use same predicate.

## Streak grace for today
currentStreak keeps run ending yesterday when today scheduled and no done/skipped log yet. Today counts missed only after passing without log. Skipped neutral, done extends. Weekly-target habits keep own in-progress week grace.

## Timed vs all-day
Habit with reminder time -> timed block (HH:mm in Habits.reminderTime; parsed to minutes on HabitCalendarEntry.timeMinutes; fixed 30 min height in hour grid). Without reminder -> all-day strip (TimelineAllDayStrip, caps rows, +N overflow). Invalid/empty reminder falls back to all-day. Month/agenda show all scheduled habits.

## Marker behavior
HabitCalendarMarker shared compact widget (all-day strip, month grid, selected-day list, agenda). Tap/long-press opens shared habit action sheet (no direct toggle). Month markers share per-day slots with events; combined before slot calc so +N more correct. Agenda/month selected-day: habits above events; day with only habits not empty.

## Action sheet
showHabitActionSheet in app/lib/features/calendar/presentation/habit_action_sheet.dart. Header: name, day, reminder time, goal progress. Actions: Mark concluded / not concluded; Add/Subtract increment unit (subtract only with positive goal); Skip/Unskip; Open habits (pops, navigates /tab3). Watches habit-log stream for live updates.

## Goal increments
HabitRepository.addAmount: create log if missing, increment amount, preserve done/skipped, mark done when goal reached, enqueue outbox update, touch habit.
subtractAmount: no-op if no log; ignore zero/negative; subtract clamped at 0; clear/set done based on goal; preserve skipped; enqueue update.
setDone(id, day, false): amount 0, done false, preserve skipped, no alarm cancel.

## Statistics
Habits app bar opens a statistics screen backed by local logs only.
- Goal habits: compliance = sum(min(amount, goal)) / sum(goal) over scheduled past days; partial days count proportionally; skipped days are neutral; future days and days before startDate are excluded. Display is capped at 100%.
- Binary habits (no positive goal): done days / scheduled past days. Skipped days stay neutral.
- Each card shows 7- and 30-day compliance, current/best streak, perfect/partial/missed/skipped counts, total logged vs goal, remaining deficit, and weekly-target progress for weekly habits.
- Recent partial/missed goal days expose a catch-up action that calls `HabitRepository.addAmount` with the exact missing amount. Catch-up is available for today and recent prior days; skipped days are excluded.
- The screen wraps at 320 dp and 3x text; no new table, package, or timer.

## Habits list selection/bulk
Long-press enters selection mode. AppBar: close, n selected, bulk archive/unarchive, delete (confirm). 6s undo buffer one SnackBar per action. Selection pruned when rows leave active list; bulk resolves live rows at action time. Back while selecting clears selection. Nothing hard-deleted.

## Layout/perf
watchCalendarEntries(fromKey,toKey): one reactive Drift query over date-key range, reads habits+habit_logs, generates day range in SQL, filters scheduling in Dart. No per-day N+1. Returns reminder time, unit, goal, increment, current amount.
calendarHabitEntriesProvider keys stream to existing calendar cache range; timeline/month/agenda share one subscription.
timelinePlacementsFor lays out events + timed habits together; habit keys use habit:<id>@<day> prefix; habits cannot become parents of events.
No schema change, no new package, no timers/polling/battery change.

## Compatibility
Calendar habit data read-only from existing tables; no columns/migrations. Archived/soft-deleted excluded. Widgets degrade to no markers when stream loading/empty. Works all platforms via Drift+Flutter widgets.

## Verification
Domain cases: daily, weekdays, interval anchored, future start exclusion, weekly availability. Repository: range stream shape, timed metadata, increments/goal completion, done/skip preservation, decrement clamping/no-op, unmark reset, skip/backfill outbox, archive exclusion, toggle. Habits screen: minus decrement, long-press selection, stale pruning, live-row bulk archive, confirmed bulk delete. Timeline: timed in hour grid at reminder; untimed all-day; overlap keeps keys distinct. Widget: tap month marker opens sheet; Mark concluded writes done log. dart format, flutter analyze, flutter test.