// Habit streak data for the Stream year level.
//
// Done days arrive as local day keys (yyyy-MM-dd). A streak run is a set of
// consecutive done days inside one month; it also breaks where the calendar
// row wraps so a ribbon never jumps between rows.
import 'year_view_data.dart';

const int _monthsPerYear = 12;
const int _daysPerWeek = 7;

class YearHabitStreak {
  const YearHabitStreak({
    required this.habitId,
    required this.doneDayKeys,
    this.colorArgb = 0xFF4CAF50,
  });

  final String habitId;
  final Set<String> doneDayKeys;
  final int colorArgb;
}

class YearStreakRun {
  const YearStreakRun({
    required this.habit,
    required this.firstDay,
    required this.lastDay,
    required this.row,
  });

  final YearHabitStreak habit;
  final int firstDay;
  final int lastDay;
  final int row;
}

/// Consecutive done days within [month], split where the calendar row wraps.
List<YearStreakRun> yearStreakRunsForMonth({
  required int year,
  required int month,
  required YearHabitStreak streak,
  required int firstDayOfWeek,
}) {
  final offset = yearFirstWeekdayOffset(
    year: year,
    month: month,
    firstDayOfWeek: firstDayOfWeek,
  );
  final doneDays = <int>[
    for (var day = 1; day <= yearDaysInMonth(year, month); day++)
      if (streak.doneDayKeys.contains(yearDayKey(DateTime(year, month, day))))
        day,
  ];
  final runs = <YearStreakRun>[];
  var start = 0;
  var previous = 0;
  for (final day in doneDays) {
    if (start == 0) {
      start = day;
      previous = day;
      continue;
    }
    final sameRow =
        (offset + day - 1) ~/ _daysPerWeek ==
        (offset + previous - 1) ~/ _daysPerWeek;
    if (day == previous + 1 && sameRow) {
      previous = day;
      continue;
    }
    runs.add(_run(streak, offset, start, previous));
    start = day;
    previous = day;
  }
  if (start != 0) runs.add(_run(streak, offset, start, previous));
  return runs;
}

YearStreakRun _run(
  YearHabitStreak streak,
  int offset,
  int firstDay,
  int lastDay,
) {
  return YearStreakRun(
    habit: streak,
    firstDay: firstDay,
    lastDay: lastDay,
    row: (offset + firstDay - 1) ~/ _daysPerWeek,
  );
}

bool yearHasData({
  required int year,
  required Map<String, int> dayCounts,
  required List<YearHabitStreak> habitStreaks,
}) {
  for (var month = 1; month <= _monthsPerYear; month++) {
    final days = yearDaysInMonth(year, month);
    for (var day = 1; day <= days; day++) {
      final key = yearDayKey(DateTime(year, month, day));
      if ((dayCounts[key] ?? 0) > 0) return true;
      for (final streak in habitStreaks) {
        if (streak.doneDayKeys.contains(key)) return true;
      }
    }
  }
  return false;
}
