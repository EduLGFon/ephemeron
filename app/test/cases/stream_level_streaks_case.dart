import 'package:ephemeron/domain/habits/habit_calendar_entry.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/habits/application/habits_providers.dart'
    show habitStreakProvider;
import 'package:ephemeron/features/stream/application/stream_ambient.dart'
    show streamAmbientHabitColorArgb;
import 'package:ephemeron/features/stream/application/stream_level_data.dart';
import 'package:ephemeron/features/stream/application/stream_level_streaks.dart';
import 'package:ephemeron/features/stream/presentation/levels/year_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

HabitCalendarEntry _entry(
  String habitId,
  String dayKey, {
  String? name,
  bool done = true,
  bool skipped = false,
}) => HabitCalendarEntry(
  habitId: habitId,
  habitName: name ?? habitId,
  dayKey: dayKey,
  done: done,
  skipped: skipped,
);

void main() {
  test(
    'year ribbons keep done days per habit and ignore skips/out of range',
    () {
      final range = streamLevelRangeFor(StreamLevel.year, DateTime(2026, 5, 1));
      final result = streamLevelHabitStreaksFrom(
        range: range,
        entries: [
          _entry('h2', '2026-12-31', name: 'Write'),
          _entry('h1', '2026-01-02', name: 'Read'),
          _entry('h1', '2026-01-03', name: 'Read'),
          _entry('h1', '2026-01-04', name: 'Read', done: false),
          _entry('h1', '2026-01-05', name: 'Read'),
          _entry('h1', '2026-01-06', name: 'Read', skipped: true),
          _entry('h3', '2025-12-31', name: 'Outside'),
        ],
      );

      expect(result.monthStreaks, isEmpty);
      expect(result.yearStreaks.map((streak) => streak.habitId), ['h1', 'h2']);
      final h1 = result.yearStreaks.first;
      expect(h1.doneDayKeys, {'2026-01-02', '2026-01-03', '2026-01-05'});
      expect(h1.colorArgb, streamAmbientHabitColorArgb);
      expect(result.yearStreaks.last.doneDayKeys, {'2026-12-31'});

      final runs = yearStreakRunsForMonth(
        year: 2026,
        month: 1,
        streak: h1,
        firstDayOfWeek: DateTime.monday,
      );
      expect(runs, hasLength(2));
      expect((runs.first.firstDay, runs.first.lastDay), (2, 3));
      expect((runs.last.firstDay, runs.last.lastDay), (5, 5));
    },
  );

  test('month ribbons use the same entries projected to day-of-month', () {
    final range = streamLevelRangeFor(
      StreamLevel.month,
      DateTime(2026, 11, 15),
    );
    final result = streamLevelHabitStreaksFrom(
      range: range,
      entries: [
        _entry('h1', '2026-11-03', name: 'Read'),
        _entry('h1', '2026-11-04', name: 'Read'),
        _entry('h1', '2026-10-31', name: 'Read'),
        _entry('h1', '2026-11-05', name: 'Read', done: false),
        _entry('h2', '2026-11-10', name: 'Write'),
      ],
    );

    expect(result.yearStreaks, isEmpty);
    expect(result.monthStreaks.map((streak) => streak.habitId), ['h1', 'h2']);
    expect(result.monthStreaks.first.doneDays, {3, 4});
    expect(result.monthStreaks.last.doneDays, {10});
    expect(result.monthStreaks.first.colorArgb, streamAmbientHabitColorArgb);
  });

  test('week ranges produce no ribbons', () {
    final result = streamLevelHabitStreaksFrom(
      range: streamLevelRangeFor(StreamLevel.week, DateTime(2026, 11, 18)),
      entries: [_entry('h1', '2026-11-18')],
    );
    expect(result.monthStreaks, isEmpty);
    expect(result.yearStreaks, isEmpty);
  });

  test('provider builds ribbons without a per-habit streak read', () async {
    final range = streamLevelRangeFor(StreamLevel.year, DateTime(2026, 5, 1));
    final entries = [_entry('h1', '2026-01-02'), _entry('h1', '2026-01-04')];
    var streakReads = 0;
    final container = ProviderContainer(
      overrides: [
        calendarHabitEntriesProvider(streamLevelQueryRange(range))
            .overrideWithValue(AsyncData(entries)),
        habitStreakProvider.overrideWith((ref, habitId) {
          streakReads++;
          return (current: 0, best: 0);
        }),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      streamLevelHabitStreaksProvider(range).future,
    );

    expect(streakReads, 0);
    expect(result.yearStreaks.single.habitId, 'h1');
    expect(result.yearStreaks.single.doneDayKeys, {'2026-01-02', '2026-01-04'});
  });
}
