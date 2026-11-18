import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/stream_day_mark.dart';
import 'level_data.dart';

part 'week_painter.dart';
part 'week_view_state.dart';

class WeekHabitDotRow {
  const WeekHabitDotRow({required this.id, required this.done});

  final String id;
  final List<bool> done;
}

class WeekView extends StatefulWidget {
  const WeekView({
    super.key,
    required this.weekStart,
    this.dayMarks,
    this.marks,
    required this.cellWidth,
    required this.cellHeight,
    this.visibleStart,
    this.visibleEnd,
    this.visibleRangeStartMs,
    this.visibleRangeEndMs,
    required this.dayHeaderBuilder,
    required this.daySemanticsLabel,
    this.habitRows,
    this.maxChips = 3,
    this.overflowLabelBuilder,
    this.onDayTap,
    this.onMarkTap,
    this.onCulledCount,
    required this.markSemanticsLabel,
    this.onCompleteMark,
    this.onPushMark,
    this.onRescheduleMark,
    this.onDeleteMark,
    required this.markActionLabels,
  });

  final DateTime weekStart;
  final List<List<StreamDayMark>>? dayMarks;
  final List<StreamDayMark>? marks;
  final double cellWidth;
  final double cellHeight;
  final DateTime? visibleStart;
  final DateTime? visibleEnd;
  final int? visibleRangeStartMs;
  final int? visibleRangeEndMs;
  final String Function(int dayIndex, DateTime date) dayHeaderBuilder;
  final String Function(int dayIndex, [DateTime? date]) daySemanticsLabel;
  final List<WeekHabitDotRow>? habitRows;
  final int maxChips;
  final String Function(int remaining)? overflowLabelBuilder;
  final void Function(DateTime date)? onDayTap;
  final void Function(String markId)? onMarkTap;
  final void Function(int culledCount)? onCulledCount;
  final String Function(StreamDayMark mark) markSemanticsLabel;
  final void Function(String markId)? onCompleteMark;
  final void Function(String markId)? onPushMark;
  final void Function(String markId)? onRescheduleMark;
  final void Function(String markId)? onDeleteMark;
  final Map<String, String> markActionLabels;

  double get resolvedHeight => cellHeight;

  @override
  State<WeekView> createState() => _WeekViewState();
}

typedef StreamWeekView = WeekView;
typedef WeekLevelView = WeekView;
