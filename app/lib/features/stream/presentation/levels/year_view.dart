import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import 'year_view_data.dart';
import 'year_view_geometry.dart';
import 'year_view_layout.dart';
import 'year_view_streaks.dart';

export 'year_view_data.dart';
export 'year_view_geometry.dart';
export 'year_view_layout.dart';
export 'year_view_streaks.dart';

part 'year_view_painter.dart';
part 'year_view_semantics.dart';
part 'year_view_state.dart';

/// Compact twelve-month overview for the Stream year level.
///
/// Data is injected as a day-keyed count map and per-habit done-day keys, so
/// the view never needs the full mark list. [visibleMonthStart] and
/// [visibleMonthEnd] cull whole months and their rows; only visible months are
/// painted and exposed to semantics.
class YearView extends StatefulWidget {
  const YearView({
    super.key,
    required this.year,
    this.dayCounts = const <String, int>{},
    this.habitStreaks = const <YearHabitStreak>[],
    required this.monthHeading,
    required this.monthSemanticsLabel,
    required this.daySemanticsLabel,
    required this.habitStreakSemanticsLabel,
    this.emptyLabel,
    this.firstDayOfWeek = DateTime.monday,
    this.visibleMonthStart,
    this.visibleMonthEnd,
    this.onDateTap,
    this.onHabitTap,
    this.onCulledCount,
    this.monthColumns = 3,
  });

  final int year;

  /// Local day key (yyyy-MM-dd) to mark count.
  final Map<String, int> dayCounts;

  final List<YearHabitStreak> habitStreaks;

  /// Caller label for a month number (1-12).
  final String Function(int month) monthHeading;

  /// Caller label combining the heading and the month count.
  final String Function(String heading, int count) monthSemanticsLabel;

  /// Caller label for one day cell.
  final String Function(DateTime date, int count) daySemanticsLabel;

  /// Caller label for one consecutive-done-day run.
  final String Function(YearHabitStreak streak, DateTime first, DateTime last)
  habitStreakSemanticsLabel;

  /// Shown instead of the grid when the year has no counts or habit days.
  final String? emptyLabel;

  final int firstDayOfWeek;

  /// Inclusive month range (1-12); null means the whole year.
  final int? visibleMonthStart;
  final int? visibleMonthEnd;

  final void Function(DateTime date)? onDateTap;
  final void Function(String habitId)? onHabitTap;

  /// Reports how many months the visible range culled.
  final void Function(int culledCount)? onCulledCount;

  final int monthColumns;

  @override
  State<YearView> createState() => _YearViewState();
}

typedef StreamYearView = YearView;
typedef YearLevelView = YearView;
