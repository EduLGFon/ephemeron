import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';

part 'month_painter.dart';
part 'month_view_state.dart';

class MonthDayData {
  const MonthDayData({required this.date, this.count = 0, this.density = 0});

  final DateTime date;
  final int count;
  final double density;
}

class MonthHabitStreak {
  const MonthHabitStreak({
    required this.habitId,
    required this.doneDays,
    this.colorArgb = 0xFF4CAF50,
    this.streakLabel = '',
  });

  final String habitId;
  final Set<int> doneDays;
  final int colorArgb;
  final String streakLabel;
}

class MonthView extends StatefulWidget {
  const MonthView({
    super.key,
    required this.month,
    this.dayCounts,
    this.dayDensities,
    this.dayData,
    this.habitStreaks,
    this.cellSize,
    this.cellWidth,
    this.cellHeight,
    this.visibleStartDay,
    this.visibleEndDay,
    this.firstDayOfWeek = DateTime.monday,
    this.onDateTap,
    this.onHabitTap,
    this.onCulledCount,
    required this.daySemanticsLabel,
    required this.streakSemanticsLabel,
  });

  final DateTime month;
  final List<int>? dayCounts;
  final List<double>? dayDensities;
  final List<MonthDayData>? dayData;
  final List<MonthHabitStreak>? habitStreaks;
  final double? cellSize;
  final double? cellWidth;
  final double? cellHeight;
  final int? visibleStartDay;
  final int? visibleEndDay;
  final int firstDayOfWeek;
  final void Function(DateTime date)? onDateTap;
  final void Function(String habitId)? onHabitTap;
  final void Function(int culledCount)? onCulledCount;
  final String Function(int day, int count) daySemanticsLabel;
  final String Function(MonthHabitStreak streak) streakSemanticsLabel;

  @override
  State<MonthView> createState() => _MonthViewState();
}

typedef StreamMonthView = MonthView;
typedef MonthLevelView = MonthView;
