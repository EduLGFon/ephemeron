import 'dart:async';

import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/domain/habits/habit_calendar_entry.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/countdowns/application/countdowns_providers.dart';
import 'package:ephemeron/features/habits/application/habits_providers.dart';
import 'package:ephemeron/features/stream/application/stream_ambient.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Habit _habit(String id, {String? name, String? reminderTime}) => Habit(
  id: id,
  name: name ?? id,
  frequency: 'daily',
  weekdaysMask: 0,
  archived: false,
  reminderTime: reminderTime,
  createdAt: 0,
  updatedAt: 0,
  dirty: false,
);

HabitCalendarEntry _entry({
  required String habitId,
  required String habitName,
  required String dayKey,
  int? timeMinutes,
  bool done = false,
}) => HabitCalendarEntry(
  habitId: habitId,
  habitName: habitName,
  dayKey: dayKey,
  timeMinutes: timeMinutes,
  done: done,
);

Countdown _countdown(String id, String title, String? targetDate) => Countdown(
  id: id,
  title: title,
  targetDate: targetDate,
  yearlyRepeat: false,
  showAge: false,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  group('habitGutterItemsFrom', () {
    test('timed and all-day habits use the current-day entry', () {
      final items = habitGutterItemsFrom(
        habits: [
          _habit('timed', name: 'Timed'),
          _habit('all', name: 'All day'),
        ],
        entries: [
          _entry(
            habitId: 'timed',
            habitName: 'Timed',
            dayKey: '2026-03-10',
            timeMinutes: 450,
            done: true,
          ),
          _entry(habitId: 'all', habitName: 'All day', dayKey: '2026-03-10'),
        ],
        streaks: const {},
        currentDayKey: '2026-03-10',
      );
      expect(items.map((i) => i.id), ['all', 'timed']);
      expect(items.last.timeMinutes, 450);
      expect(items.first.timeMinutes, isNull);
      expect(items.last.doneByDay, {'2026-03-10': true});
    });

    test('streaks and done days come from their maps', () {
      final items = habitGutterItemsFrom(
        habits: [_habit('h1')],
        entries: [
          _entry(habitId: 'h1', habitName: 'h1', dayKey: '2026-03-09'),
          _entry(
            habitId: 'h1',
            habitName: 'h1',
            dayKey: '2026-03-10',
            done: true,
          ),
        ],
        streaks: const {'h1': (current: 3, best: 7)},
        currentDayKey: '2026-03-10',
      );
      expect(items.single.doneByDay, {'2026-03-09': false, '2026-03-10': true});
      expect(items.single.streakCurrent, 3);
      expect(items.single.streakBest, 7);
    });

    test('colour falls back to the caller default', () {
      final items = habitGutterItemsFrom(
        habits: [_habit('h1')],
        entries: const [],
        streaks: const {},
        currentDayKey: '2026-03-10',
        defaultColorArgb: 0xFF010203,
      );
      expect(items.single.colorArgb, 0xFF010203);
      final resolved = habitGutterItemsFrom(
        habits: [_habit('h1')],
        entries: const [],
        streaks: const {},
        currentDayKey: '2026-03-10',
        colorFor: (_) => 0xFF040506,
      );
      expect(resolved.single.colorArgb, 0xFF040506);
    });

    test('order is deterministic by time, name then id', () {
      final items = habitGutterItemsFrom(
        habits: [
          _habit('b', name: 'Same'),
          _habit('a', name: 'Same'),
          _habit('all', name: 'Z'),
          _habit('c', name: 'Early'),
          _habit('d', name: 'Alpha'),
        ],
        entries: [
          _entry(habitId: 'a', habitName: 'Same', dayKey: 'd', timeMinutes: 60),
          _entry(habitId: 'b', habitName: 'Same', dayKey: 'd', timeMinutes: 60),
          _entry(
            habitId: 'c',
            habitName: 'Early',
            dayKey: 'd',
            timeMinutes: 30,
          ),
          _entry(
            habitId: 'd',
            habitName: 'Alpha',
            dayKey: 'd',
            timeMinutes: 60,
          ),
        ],
        streaks: const {},
        currentDayKey: 'd',
      );
      expect(items.map((i) => i.id), ['all', 'c', 'd', 'a', 'b']);
    });

    test('empty inputs return an empty list', () {
      expect(
        habitGutterItemsFrom(
          habits: const [],
          entries: const [],
          streaks: const {},
          currentDayKey: '2026-03-10',
        ),
        isEmpty,
      );
    });

    test('500 habits map deterministically', () {
      final habits = [
        for (var i = 0; i < 500; i++)
          _habit('h${i.toString().padLeft(3, '0')}', name: 'Habit $i'),
      ];
      final entries = [
        for (var i = 0; i < 500; i++)
          _entry(
            habitId: habits[i].id,
            habitName: habits[i].name,
            dayKey: '2026-03-10',
            timeMinutes: i % 1440,
          ),
      ];
      final items = habitGutterItemsFrom(
        habits: habits,
        entries: entries,
        streaks: const {},
        currentDayKey: '2026-03-10',
      );
      expect(items.length, 500);
      final times = items.map((i) => i.timeMinutes!).toList();
      expect(times, orderedEquals([...times]..sort()));
      expect(
        habitGutterItemsFrom(
          habits: habits,
          entries: entries,
          streaks: const {},
          currentDayKey: '2026-03-10',
        ).map((i) => i.id),
        items.map((i) => i.id),
      );
    });
  });

  group('countdownLandmarkItemsFrom', () {
    test('valid target date yields a day key and local midnight', () {
      final item = countdownLandmarkItemsFrom([
        _countdown('c1', 'Trip', '2026-03-10'),
      ]).single;
      expect(item.targetDayKey, '2026-03-10');
      expect(item.targetMs, DateTime(2026, 3, 10).millisecondsSinceEpoch);
    });

    test('invalid and missing targets have no targetMs', () {
      final items = countdownLandmarkItemsFrom([
        _countdown('bad', 'Bad', '2026-02-30'),
        _countdown('none', 'None', null),
      ]);
      final bad = items.firstWhere((i) => i.id == 'bad');
      expect(bad.targetDayKey, '2026-02-30');
      expect(bad.targetMs, isNull);
      final none = items.firstWhere((i) => i.id == 'none');
      expect(none.targetDayKey, isNull);
      expect(none.targetMs, isNull);
    });

    test('colour falls back to the caller default', () {
      final items = countdownLandmarkItemsFrom([
        _countdown('c1', 'Trip', '2026-03-10'),
      ], defaultColorArgb: 0xFF010203);
      expect(items.single.colorArgb, 0xFF010203);
    });

    test('order is deterministic by date, title then id', () {
      final items = countdownLandmarkItemsFrom([
        _countdown('b', 'B', '2026-05-01'),
        _countdown('a', 'A', '2026-01-01'),
        _countdown('a2', 'A2', '2026-01-01'),
        _countdown('m', 'M', null),
      ]);
      expect(items.map((i) => i.id), ['a', 'a2', 'b', 'm']);
    });

    test('empty list returns an empty list', () {
      expect(countdownLandmarkItemsFrom(const []), isEmpty);
    });
  });

  group('ambient providers', () {
    test('habit items follow habit, entry and streak sources', () async {
      final habits = StreamController<List<Habit>>.broadcast();
      final entries = StreamController<List<HabitCalendarEntry>>.broadcast();
      final container = ProviderContainer(
        overrides: [
          habitsProvider.overrideWith((ref, _) => habits.stream),
          calendarHabitEntriesProvider.overrideWith((ref, _) => entries.stream),
          habitStreakProvider.overrideWith(
            (ref, _) async => (current: 4, best: 9),
          ),
        ],
      );
      const range = StreamHabitRange(
        fromKey: '2026-03-01',
        toKey: '2026-03-31',
        currentDayKey: '2026-03-10',
      );
      final sub = container.listen(
        streamHabitGutterItemsProvider(range),
        (_, _) {},
      );
      addTearDown(() async {
        sub.close();
        container.dispose();
        await habits.close();
        await entries.close();
      });
      final timed = _habit('h1', name: 'Run', reminderTime: '07:30');
      final allDay = _habit('h2', name: 'Read');
      habits.add([timed]);
      entries.add([
        _entry(
          habitId: 'h1',
          habitName: 'Run',
          dayKey: '2026-03-10',
          timeMinutes: 450,
          done: true,
        ),
      ]);
      await pumpEventQueue();
      var items = await container.read(
        streamHabitGutterItemsProvider(range).future,
      );
      expect(items.single.id, 'h1');
      expect(items.single.timeMinutes, 450);
      expect(items.single.doneByDay['2026-03-10'], isTrue);
      expect(items.single.streakCurrent, 4);
      expect(items.single.streakBest, 9);
      expect(items.single.colorArgb, streamAmbientHabitColorArgb);

      habits.add([timed, allDay]);
      await pumpEventQueue();
      items = await container.read(
        streamHabitGutterItemsProvider(range).future,
      );
      expect(items.map((i) => i.id), ['h2', 'h1']);
      expect(items.first.timeMinutes, isNull);
    });

    test('countdown items follow the countdown source', () async {
      final countdowns = StreamController<List<Countdown>>.broadcast();
      final container = ProviderContainer(
        overrides: [
          countdownsProvider.overrideWith((ref) => countdowns.stream),
        ],
      );
      final sub = container.listen(
        streamCountdownLandmarkItemsProvider,
        (_, _) {},
      );
      addTearDown(() async {
        sub.close();
        container.dispose();
        await countdowns.close();
      });
      countdowns.add([
        _countdown('c2', 'Later', '2026-05-01'),
        _countdown('c1', 'Soon', '2026-03-10'),
      ]);
      await pumpEventQueue();
      var items = await container.read(
        streamCountdownLandmarkItemsProvider.future,
      );
      expect(items.map((i) => i.id), ['c1', 'c2']);
      expect(
        items.first.targetMs,
        DateTime(2026, 3, 10).millisecondsSinceEpoch,
      );

      countdowns.add([_countdown('c3', 'New', '2026-04-01')]);
      await pumpEventQueue();
      items = await container.read(streamCountdownLandmarkItemsProvider.future);
      expect(items.single.id, 'c3');
    });
  });
}
