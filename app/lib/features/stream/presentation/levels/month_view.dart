import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Per-day data for month level.
class MonthDayData {
  const MonthDayData({required this.date, this.count = 0, this.density = 0});

  final DateTime date;
  final int count;
  final double density;
}

/// Habit streak line at month level.
class MonthHabitStreak {
  const MonthHabitStreak({
    required this.habitId,
    required this.doneDays,
    this.colorArgb = 0xFF4CAF50,
    this.streakLabel = '',
  });

  final String habitId;
  final Set<int> doneDays; // day-of-month (1-based) that are done
  final int colorArgb;
  final String streakLabel;
}

/// L4 month level: density grid plus habit streak lines. Presentation only.
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
    this.onDateTap,
    this.onHabitTap,
    this.onCulledCount,
    this.daySemanticsLabel,
    this.streakSemanticsLabel,
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
  final void Function(DateTime date)? onDateTap;
  final void Function(String habitId)? onHabitTap;
  final void Function(int culledCount)? onCulledCount;
  final String Function(int day, int count)? daySemanticsLabel;
  final String Function(MonthHabitStreak streak)? streakSemanticsLabel;

  @override
  State<MonthView> createState() => _MonthViewState();
}

typedef StreamMonthView = MonthView;
typedef MonthLevelView = MonthView;

class _MonthViewState extends State<MonthView> {
  int _daysInMonth() {
    final m = widget.month;
    final next = DateTime(m.year, m.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  int _firstWeekdayOffset() {
    // Monday-based offset (0..6). Use month's first day weekday.
    final first = DateTime(widget.month.year, widget.month.month, 1);
    // Dart weekday: Mon=1..Sun=7. Convert to 0-based Mon.
    return (first.weekday - DateTime.monday + 7) % 7;
  }

  int _count(int day) {
    if (widget.dayData != null) {
      for (final d in widget.dayData!) {
        if (d.date.day == day && d.date.month == widget.month.month) {
          return d.count;
        }
      }
    }
    if (widget.dayCounts != null && day - 1 < widget.dayCounts!.length) {
      return widget.dayCounts![day - 1];
    }
    return 0;
  }

  double _density(int day) {
    if (widget.dayData != null) {
      for (final d in widget.dayData!) {
        if (d.date.day == day && d.date.month == widget.month.month) {
          return d.density;
        }
      }
    }
    if (widget.dayDensities != null && day - 1 < widget.dayDensities!.length) {
      return widget.dayDensities![day - 1];
    }
    final c = _count(day);
    // normalize against max count
    var maxC = 1;
    for (var d = 1; d <= _daysInMonth(); d++) {
      final cc = _count(d);
      if (cc > maxC) maxC = cc;
    }
    return (c / maxC).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cellSize ?? widget.cellWidth ?? widget.cellHeight ?? 40.0;
    final days = _daysInMonth();
    final offset = _firstWeekdayOffset();
    final rows = ((offset + days) / 7).ceil();
    final size = Size(cs * 7, cs * rows);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        // habit streak hit test: check if tap near a done dot line
        // Simple: map to date first.
        final col = (details.localPosition.dx / cs).floor().clamp(0, 6);
        final row = (details.localPosition.dy / cs).floor();
        final idx = row * 7 + col - offset;
        final day = idx + 1;
        if (day >= 1 && day <= days) {
          // check habit streaks: if tap in lower third of cell, treat as habit
          final inCellY = details.localPosition.dy - row * cs;
          if (inCellY > cs * 0.66) {
            final streaks = widget.habitStreaks ?? const <MonthHabitStreak>[];
            if (streaks.isNotEmpty) {
              widget.onHabitTap?.call(streaks.first.habitId);
              return;
            }
          }
          widget.onDateTap?.call(
            DateTime(widget.month.year, widget.month.month, day),
          );
        }
      },
      child: CustomPaint(
        painter: _MonthPainter(
          month: widget.month,
          daysInMonth: days,
          firstOffset: offset,
          cellSize: cs,
          countOf: _count,
          densityOf: _density,
          habitStreaks: widget.habitStreaks ?? const <MonthHabitStreak>[],
          visibleStartDay: widget.visibleStartDay,
          visibleEndDay: widget.visibleEndDay,
          textScale: textScale,
          onCulledCount: widget.onCulledCount,
          daySemanticsLabel: widget.daySemanticsLabel,
          streakSemanticsLabel: widget.streakSemanticsLabel,
        ),
        size: size,
      ),
    );
  }
}

class _MonthPainter extends CustomPainter {
  _MonthPainter({
    required this.month,
    required this.daysInMonth,
    required this.firstOffset,
    required this.cellSize,
    required this.countOf,
    required this.densityOf,
    required this.habitStreaks,
    this.visibleStartDay,
    this.visibleEndDay,
    required this.textScale,
    this.onCulledCount,
    this.daySemanticsLabel,
    this.streakSemanticsLabel,
  });

  final DateTime month;
  final int daysInMonth;
  final int firstOffset;
  final double cellSize;
  final int Function(int day) countOf;
  final double Function(int day) densityOf;
  final List<MonthHabitStreak> habitStreaks;
  final int? visibleStartDay;
  final int? visibleEndDay;
  final double textScale;
  final void Function(int)? onCulledCount;
  final String Function(int day, int count)? daySemanticsLabel;
  final String Function(MonthHabitStreak streak)? streakSemanticsLabel;

  bool _visible(int day) {
    if (visibleStartDay != null && day < visibleStartDay!) return false;
    if (visibleEndDay != null && day > visibleEndDay!) return false;
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    var culled = 0;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var day = 1; day <= daysInMonth; day++) {
      if (!_visible(day)) continue;
      culled++;
      final rect = _cellRect(day);
      final density = densityOf(day);
      final count = countOf(day);
      // density bar
      final barH = cellSize * 0.35 * density.clamp(0.0, 1.0);
      paint.color = const Color(0xFF90CAF9);
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + 2,
          rect.bottom - barH - 2,
          rect.width - 4,
          barH,
        ),
        paint,
      );
      // count
      final tp = TextPainter(
        text: TextSpan(
          text: '$count',
          style: TextStyle(
            fontSize: 10 * textScale,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      tp.layout(maxWidth: rect.width - 2);
      tp.paint(canvas, Offset(rect.left + 2, rect.top + 2));
    }
    // habit streak lines
    for (final streak in habitStreaks) {
      final sorted = streak.doneDays.toList()..sort();
      // group consecutive
      List<int> current = <int>[];
      final groups = <List<int>>[];
      for (final d in sorted) {
        if (current.isEmpty || d == current.last + 1) {
          current.add(d);
        } else {
          groups.add(current);
          current = <int>[d];
        }
      }
      if (current.isNotEmpty) groups.add(current);
      for (final g in groups) {
        if (g.isEmpty) continue;
        final startRect = _cellRect(g.first);
        final endRect = _cellRect(g.last);
        final y =
            (startRect.center.dy + endRect.center.dy) / 2 + cellSize * 0.15;
        paint.color = Color(streak.colorArgb);
        paint.strokeWidth = 2;
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(startRect.center.dx, y),
          Offset(endRect.center.dx, y),
          paint,
        );
        paint.style = PaintingStyle.fill;
        // dots
        for (final d in g) {
          final r = _cellRect(d);
          canvas.drawCircle(
            Offset(r.center.dx, y),
            2.5,
            paint..color = Color(streak.colorArgb),
          );
        }
      }
    }
    onCulledCount?.call(culled);
  }

  Rect _cellRect(int day) {
    final offset = firstOffset;
    final idx = offset + (day - 1);
    final col = idx % 7;
    final row = idx ~/ 7;
    return Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize);
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    final result = <CustomPainterSemantics>[];
    for (var day = 1; day <= daysInMonth; day++) {
      if (!_visible(day)) continue;
      final rect = _cellRect(day);
      final count = countOf(day);
      final label = daySemanticsLabel != null
          ? daySemanticsLabel!(day, count)
          : 'Day $day: $count';
      result.add(
        CustomPainterSemantics(
          rect: rect,
          properties: SemanticsProperties(
            label: label,
            textDirection: TextDirection.ltr,
          ),
        ),
      );
    }
    for (final streak in habitStreaks) {
      // one node per contiguous group
      final sorted = streak.doneDays.toList()..sort();
      List<int> current = <int>[];
      final groups = <List<int>>[];
      for (final d in sorted) {
        if (current.isEmpty || d == current.last + 1) {
          current.add(d);
        } else {
          groups.add(current);
          current = <int>[d];
        }
      }
      if (current.isNotEmpty) groups.add(current);
      for (final g in groups) {
        if (g.isEmpty) continue;
        final startRect = _cellRect(g.first);
        final endRect = _cellRect(g.last);
        if (endRect.right < startRect.left) {
          continue; // wrapped row: skip invisible node
        }
        final y =
            (startRect.center.dy + endRect.center.dy) / 2 + cellSize * 0.15;
        result.add(
          CustomPainterSemantics(
            rect: Rect.fromLTWH(
              startRect.left,
              y - 4,
              math.max(0.0, endRect.right - startRect.left),
              8,
            ),
            properties: SemanticsProperties(
              label: streakSemanticsLabel != null
                  ? streakSemanticsLabel!(streak)
                  : '${streak.habitId}: ${streak.streakLabel}',
              textDirection: TextDirection.ltr,
            ),
          ),
        );
      }
    }
    return result;
  };

  @override
  bool shouldRepaint(covariant _MonthPainter oldDelegate) => true;
}
