// Habit streak ribbons for the Stream month and year levels.
//
// One batch of calendar habit entries feeds every ribbon, so the level never
// fans out to a streak query per habit (see stream_ambient.dart). Drift habits
// have no colour column, so ribbons share the ambient habit colour until a
// colour source exists. See ARCHITECTURE.md.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/habits/date_key.dart';
import '../../../domain/habits/habit_calendar_entry.dart';
import '../../calendar/application/calendar_providers.dart'
    show calendarHabitEntriesProvider;
import '../presentation/levels/month_view.dart' show MonthHabitStreak;
import '../presentation/levels/year_view.dart' show YearHabitStreak;
import 'stream_ambient.dart' show streamAmbientHabitColorArgb;
import 'stream_level_data.dart';

/// Ribbon data for the visible level range.
///
/// Only the list matching the range level is populated; the other stays empty
/// so a caller cannot accidentally show month days on the year level.
class StreamLevelHabitStreaks {
  const StreamLevelHabitStreaks({
    this.monthStreaks = const <MonthHabitStreak>[],
    this.yearStreaks = const <YearHabitStreak>[],
  });

  final List<MonthHabitStreak> monthStreaks;
  final List<YearHabitStreak> yearStreaks;
}

/// Projects the done days in [entries] onto the ribbon type for [range].
///
/// Entries outside the local range, not done, or skipped are ignored. Habits
/// are ordered by name then id so the year ribbon lanes stay stable across
/// rebuilds. No provider is read here, which keeps the mapping pure.
StreamLevelHabitStreaks streamLevelHabitStreaksFrom({
  required StreamLevelRange range,
  required List<HabitCalendarEntry> entries,
  int colorArgb = streamAmbientHabitColorArgb,
}) {
  final lastDay = DateTime(range.end.year, range.end.month, range.end.day - 1);
  final fromKey = habitDateKey(range.start);
  final toKey = habitDateKey(lastDay);
  final doneByHabit = <String, Set<String>>{};
  final names = <String, String>{};
  for (final entry in entries) {
    if (!entry.done || entry.skipped) continue;
    final key = entry.dayKey;
    if (key.compareTo(fromKey) < 0 || key.compareTo(toKey) > 0) continue;
    (doneByHabit[entry.habitId] ??= <String>{}).add(key);
    names[entry.habitId] = entry.habitName;
  }

  final habitIds = doneByHabit.keys.toList(growable: false)
    ..sort((a, b) {
      final byName = (names[a] ?? '').compareTo(names[b] ?? '');
      return byName != 0 ? byName : a.compareTo(b);
    });

  switch (range.level) {
    case StreamLevel.month:
      final monthStreaks = <MonthHabitStreak>[];
      for (final habitId in habitIds) {
        final doneDays = <int>{};
        for (final key in doneByHabit[habitId]!) {
          final day = DateTime.tryParse(key);
          if (day == null) continue;
          if (day.year != range.start.year || day.month != range.start.month) {
            continue;
          }
          doneDays.add(day.day);
        }
        if (doneDays.isEmpty) continue;
        monthStreaks.add(
          MonthHabitStreak(
            habitId: habitId,
            doneDays: doneDays,
            colorArgb: colorArgb,
          ),
        );
      }
      return StreamLevelHabitStreaks(monthStreaks: monthStreaks);
    case StreamLevel.year:
      final yearStreaks = <YearHabitStreak>[];
      for (final habitId in habitIds) {
        yearStreaks.add(
          YearHabitStreak(
            habitId: habitId,
            doneDayKeys: doneByHabit[habitId]!,
            colorArgb: colorArgb,
          ),
        );
      }
      return StreamLevelHabitStreaks(yearStreaks: yearStreaks);
    case StreamLevel.day:
    case StreamLevel.week:
      return const StreamLevelHabitStreaks();
  }
}

/// Ribbons for one month or year range.
///
/// Reads the same batch [calendarHabitEntriesProvider] the calendar uses; it
/// never watches a per-habit streak provider.
final streamLevelHabitStreaksProvider =
    FutureProvider.family<StreamLevelHabitStreaks, StreamLevelRange>((
      ref,
      range,
    ) async {
      final entries = await ref.watch(
        calendarHabitEntriesProvider(streamLevelQueryRange(range)).future,
      );
      return streamLevelHabitStreaksFrom(range: range, entries: entries);
    });
