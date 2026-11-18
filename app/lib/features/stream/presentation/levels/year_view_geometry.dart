// Geometry value types for the Stream year level. Layout is produced by
// year_view_layout.dart; painter, hit testing and semantics share the result.
import 'dart:ui' show Offset, Rect, Size;

import 'year_view_streaks.dart';

class YearDayGeometry {
  const YearDayGeometry({
    required this.date,
    required this.count,
    required this.density,
    required this.rect,
  });

  final DateTime date;
  final int count;
  final double density;
  final Rect rect;
}

class YearStreakGeometry {
  const YearStreakGeometry({
    required this.habit,
    required this.firstDay,
    required this.lastDay,
    required this.start,
    required this.end,
    required this.rect,
  });

  final YearHabitStreak habit;
  final int firstDay;
  final int lastDay;
  final Offset start;
  final Offset end;
  final Rect rect;
}

class YearMonthGeometry {
  const YearMonthGeometry({
    required this.month,
    required this.rect,
    required this.headerRect,
    required this.gridRect,
    required this.cellSize,
    required this.totalCount,
    required this.days,
    required this.streaks,
  });

  final int month;
  final Rect rect;
  final Rect headerRect;
  final Rect gridRect;
  final double cellSize;
  final int totalCount;
  final List<YearDayGeometry> days;
  final List<YearStreakGeometry> streaks;
}

class YearViewGeometry {
  const YearViewGeometry({
    required this.year,
    required this.size,
    required this.months,
  });

  final int year;
  final Size size;
  final List<YearMonthGeometry> months;
}
