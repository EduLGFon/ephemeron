// Read-only ambient projection of habits and countdowns onto Stream items.
//
// Pure mapping plus Riverpod providers over the existing habit/countdown
// sources. No UI and no writes. Drift Habit/Countdown rows have no colour
// column, so callers supply the default (and may pass a resolver for a future
// colour source).
//
// Streaks are lazy: the gutter provider never fans out per habit. Items carry
// 0/0; the surface asks [streamHabitStreakProvider] for the single habit whose
// streak it shows. See ARCHITECTURE.md.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drift/app_database.dart' show Countdown, Habit;
import '../../../domain/habits/habit_calendar_entry.dart';
import '../../calendar/application/calendar_providers.dart'
    show calendarHabitEntriesProvider;
import '../../calendar/application/calendar_state.dart' show CalendarRange;
import '../../countdowns/application/countdowns_providers.dart'
    show countdownsProvider;
import '../../habits/application/habits_providers.dart'
    show habitStreakProvider, habitsProvider;
import '../presentation/countdowns/countdown_landmark_item.dart';
import '../presentation/habits/habit_gutter_item.dart';

const int streamAmbientHabitColorArgb = 0xFF4CAF50;
const int streamAmbientCountdownColorArgb = 0xFF1976D2;

/// Inclusive local day-key window plus the day the gutter renders.
class StreamHabitRange {
  const StreamHabitRange({
    required this.fromKey,
    required this.toKey,
    required this.currentDayKey,
  });

  final String fromKey;
  final String toKey;
  final String currentDayKey;

  @override
  bool operator ==(Object other) =>
      other is StreamHabitRange &&
      other.fromKey == fromKey &&
      other.toKey == toKey &&
      other.currentDayKey == currentDayKey;

  @override
  int get hashCode => Object.hash(fromKey, toKey, currentDayKey);
}

/// One gutter item per habit in [habits]. Entries only supply the time for
/// [currentDayKey] and the done state per day. Ordered all-day first, then by
/// time, name, id.
List<HabitGutterItem> habitGutterItemsFrom({
  required List<Habit> habits,
  required List<HabitCalendarEntry> entries,
  required Map<String, ({int current, int best})> streaks,
  required String currentDayKey,
  int defaultColorArgb = streamAmbientHabitColorArgb,
  int Function(Habit habit)? colorFor,
}) {
  final timeByHabitDay = <String, int?>{};
  final doneByHabit = <String, Map<String, bool>>{};
  for (final entry in entries) {
    timeByHabitDay['${entry.habitId}\u0000${entry.dayKey}'] = entry.timeMinutes;
    (doneByHabit[entry.habitId] ??= <String, bool>{})[entry.dayKey] =
        entry.done;
  }
  final items = <HabitGutterItem>[
    for (final habit in habits)
      HabitGutterItem(
        id: habit.id,
        name: habit.name,
        colorArgb: colorFor?.call(habit) ?? defaultColorArgb,
        timeMinutes: timeByHabitDay['${habit.id}\u0000$currentDayKey'],
        doneByDay: doneByHabit[habit.id] ?? const <String, bool>{},
        streakCurrent: streaks[habit.id]?.current ?? 0,
        streakBest: streaks[habit.id]?.best ?? 0,
      ),
  ];
  items.sort(_compareHabitItems);
  return items;
}

int _compareHabitItems(HabitGutterItem a, HabitGutterItem b) {
  final at = a.timeMinutes;
  final bt = b.timeMinutes;
  if (at != bt) {
    if (at == null) return -1;
    if (bt == null) return 1;
    final byTime = at.compareTo(bt);
    if (byTime != 0) return byTime;
  }
  final byName = a.name.compareTo(b.name);
  return byName != 0 ? byName : a.id.compareTo(b.id);
}

/// One landmark per countdown. [targetDayKey] keeps the stored date string;
/// [targetMs] is local midnight only when that string is a valid date.
/// Ordered by target date (missing last), title, id.
List<CountdownLandmarkItem> countdownLandmarkItemsFrom(
  List<Countdown> countdowns, {
  int defaultColorArgb = streamAmbientCountdownColorArgb,
  int Function(Countdown countdown)? colorFor,
}) {
  final items = <CountdownLandmarkItem>[
    for (final countdown in countdowns)
      CountdownLandmarkItem(
        id: countdown.id,
        title: countdown.title,
        targetDayKey: countdown.targetDate,
        targetMs: _parseDayKey(countdown.targetDate)?.millisecondsSinceEpoch,
        colorArgb: colorFor?.call(countdown) ?? defaultColorArgb,
      ),
  ];
  items.sort(_compareCountdownItems);
  return items;
}

int _compareCountdownItems(CountdownLandmarkItem a, CountdownLandmarkItem b) {
  final ak = a.targetDayKey;
  final bk = b.targetDayKey;
  if (ak != bk) {
    if (ak == null) return 1;
    if (bk == null) return -1;
    final byDay = ak.compareTo(bk);
    if (byDay != 0) return byDay;
  }
  final byTitle = a.title.compareTo(b.title);
  return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
}

DateTime? _parseDayKey(String? key) {
  if (key == null) return null;
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > DateTime(year, month + 1, 0).day) return null;
  return DateTime(year, month, day);
}

CalendarRange _calendarRangeFor(StreamHabitRange range) {
  final from = _parseDayKey(range.fromKey);
  final to = _parseDayKey(range.toKey);
  if (from == null || to == null) {
    throw FormatException('Invalid StreamHabitRange', range);
  }
  return CalendarRange(
    fromUtc: DateTime.utc(from.year, from.month, from.day),
    toUtc: DateTime.utc(to.year, to.month, to.day + 1),
  );
}

/// Single-habit streak lookup for the surface. Call it only for the habit
/// whose streak is currently shown (long-press/completion), never per row.
final streamHabitStreakProvider =
    FutureProvider.family<({int current, int best}), String>((ref, habitId) {
      return ref.watch(habitStreakProvider(habitId).future);
    });

/// Gutter items for [range]. Streaks are intentionally not loaded here; one
/// query per habit would fan out to hundreds of habit/log reads. Items carry
/// 0/0 and callers use [streamHabitStreakProvider] for the visible habit.
final streamHabitGutterItemsProvider =
    StreamProvider.family<List<HabitGutterItem>, StreamHabitRange>((
      ref,
      range,
    ) {
      final habitsAsync = ref.watch(habitsProvider(false));
      final entriesAsync = ref.watch(
        calendarHabitEntriesProvider(_calendarRangeFor(range)),
      );
      if (habitsAsync.hasError) {
        return Stream.error(habitsAsync.error!, habitsAsync.stackTrace);
      }
      if (entriesAsync.hasError) {
        return Stream.error(entriesAsync.error!, entriesAsync.stackTrace);
      }
      final habits = habitsAsync.value;
      final entries = entriesAsync.value;
      if (habits == null || entries == null) return const Stream.empty();
      return Stream.value(
        habitGutterItemsFrom(
          habits: habits,
          entries: entries,
          streaks: const {},
          currentDayKey: range.currentDayKey,
        ),
      );
    });

final streamCountdownLandmarkItemsProvider =
    StreamProvider<List<CountdownLandmarkItem>>((ref) {
      final countdownsAsync = ref.watch(countdownsProvider);
      if (countdownsAsync.hasError) {
        return Stream.error(countdownsAsync.error!, countdownsAsync.stackTrace);
      }
      final countdowns = countdownsAsync.value;
      if (countdowns == null) return const Stream.empty();
      return Stream.value(countdownLandmarkItemsFrom(countdowns));
    });
