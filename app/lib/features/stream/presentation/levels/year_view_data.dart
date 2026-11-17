// Pure aggregate data for the Stream year level.
//
// Day keys are local calendar dates formatted yyyy-MM-dd, matching
// habit_streak_line.dart. Counts and density are independent of rendering;
// the painter, geometry and tests share these helpers.
import 'dart:math' as math;

const int _monthsPerYear = 12;
const int _daysPerWeek = 7;

String yearDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

int yearDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

int yearFirstWeekdayOffset({
  required int year,
  required int month,
  required int firstDayOfWeek,
}) {
  final first = DateTime(year, month, 1);
  return (first.weekday - firstDayOfWeek + _daysPerWeek) % _daysPerWeek;
}

int yearWeekRows({
  required int year,
  required int month,
  required int firstDayOfWeek,
}) {
  final offset = yearFirstWeekdayOffset(
    year: year,
    month: month,
    firstDayOfWeek: firstDayOfWeek,
  );
  return (offset + yearDaysInMonth(year, month) + _daysPerWeek - 1) ~/
      _daysPerWeek;
}

int yearMaxDayCount(int year, Map<String, int> dayCounts) {
  var max = 0;
  for (var month = 1; month <= _monthsPerYear; month++) {
    final days = yearDaysInMonth(year, month);
    for (var day = 1; day <= days; day++) {
      final count = dayCounts[yearDayKey(DateTime(year, month, day))] ?? 0;
      if (count > max) max = count;
    }
  }
  return max;
}

class YearDayData {
  const YearDayData({
    required this.date,
    required this.count,
    required this.density,
  });

  final DateTime date;
  final int count;
  final double density;
}

class YearMonthData {
  const YearMonthData({
    required this.month,
    required this.days,
    required this.totalCount,
    required this.firstWeekdayOffset,
    required this.weekRows,
  });

  final int month;
  final List<YearDayData> days;
  final int totalCount;
  final int firstWeekdayOffset;
  final int weekRows;
}

YearMonthData buildYearMonthData({
  required int year,
  required int month,
  required Map<String, int> dayCounts,
  int? maxCount,
  int firstDayOfWeek = DateTime.monday,
}) {
  final max = maxCount ?? yearMaxDayCount(year, dayCounts);
  final denominator = max <= 0 ? 1 : max;
  final days = <YearDayData>[];
  var total = 0;
  final dayCount = yearDaysInMonth(year, month);
  for (var day = 1; day <= dayCount; day++) {
    final date = DateTime(year, month, day);
    final count = dayCounts[yearDayKey(date)] ?? 0;
    total += count;
    days.add(
      YearDayData(
        date: date,
        count: count,
        density: (count / denominator).clamp(0.0, 1.0),
      ),
    );
  }
  return YearMonthData(
    month: month,
    days: days,
    totalCount: total,
    firstWeekdayOffset: yearFirstWeekdayOffset(
      year: year,
      month: month,
      firstDayOfWeek: firstDayOfWeek,
    ),
    weekRows: yearWeekRows(
      year: year,
      month: month,
      firstDayOfWeek: firstDayOfWeek,
    ),
  );
}

List<int> yearVisibleMonths({int? startMonth, int? endMonth}) {
  final start = math.max(1, math.min(_monthsPerYear, startMonth ?? 1));
  final end = math.max(1, math.min(_monthsPerYear, endMonth ?? _monthsPerYear));
  if (start > end) return const <int>[];
  return <int>[for (var month = start; month <= end; month++) month];
}
