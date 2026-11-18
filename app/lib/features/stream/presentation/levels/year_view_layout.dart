// Layout for the Stream year level. Pure logical-pixel geometry relative to
// the YearView origin; the painter, hit testing, semantics and tests share it.
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'year_view_data.dart';
import 'year_view_geometry.dart';
import 'year_view_streaks.dart';

part 'year_view_metrics.dart';
part 'year_view_month_layout.dart';

const double _outerPadding = 8;
const double _columnGap = 8;
const double _rowGap = 10;
const double _innerPadding = 4;
const double _headerGap = 2;
const int _maxWeekRows = 6;
const double _headerTextHeight = 14;
const double _streakSpread = 0.5;

YearViewGeometry buildYearViewGeometry({
  required int year,
  required double width,
  required double textScale,
  required Map<String, int> dayCounts,
  required List<YearHabitStreak> habitStreaks,
  required int firstDayOfWeek,
  int monthColumns = 3,
  int? visibleMonthStart,
  int? visibleMonthEnd,
}) {
  final visible = yearVisibleMonths(
    startMonth: visibleMonthStart,
    endMonth: visibleMonthEnd,
  );
  final columns = math.max(1, monthColumns);
  final metrics = _YearMetrics.compute(
    width: width,
    textScale: textScale,
    columns: columns,
    visible: visible,
  );
  return YearViewGeometry(
    year: year,
    size: Size(width, metrics.height),
    months: <YearMonthGeometry>[
      for (final month in visible)
        _monthGeometry(
          year: year,
          month: month,
          columns: columns,
          metrics: metrics,
          dayCounts: dayCounts,
          habitStreaks: habitStreaks,
          firstDayOfWeek: firstDayOfWeek,
        ),
    ],
  );
}
