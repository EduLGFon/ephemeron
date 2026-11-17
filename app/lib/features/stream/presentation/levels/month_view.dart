import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';

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

class _MonthViewState extends State<MonthView> {
  int _daysInMonth() {
    final m = widget.month;
    final next = DateTime(m.year, m.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  int _firstWeekdayOffset() {
    final first = DateTime(widget.month.year, widget.month.month, 1);
    return (first.weekday - widget.firstDayOfWeek + 7) % 7;
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
    var maxC = 1;
    for (var d = 1; d <= _daysInMonth(); d++) {
      final cc = _count(d);
      if (cc > maxC) maxC = cc;
    }
    return (c / maxC).clamp(0.0, 1.0);
  }

  bool _visible(int day) {
    if (widget.visibleStartDay != null && day < widget.visibleStartDay!) {
      return false;
    }
    if (widget.visibleEndDay != null && day > widget.visibleEndDay!) {
      return false;
    }
    return true;
  }

  int? _lastCulled;

  void _scheduleCulled() {
    final days = _daysInMonth();
    final visible = List.generate(days, (i) => i + 1).where(_visible).length;
    final value = days - visible;
    if (value == _lastCulled) return;
    _lastCulled = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCulledCount?.call(value);
    });
  }

  double _cellSize(BuildContext context) {
    return widget.cellSize ?? widget.cellWidth ?? widget.cellHeight ?? 40.0;
  }

  Rect _cellRect(int day, double cs) {
    final offset = _firstWeekdayOffset();
    final idx = offset + (day - 1);
    final col = idx % 7;
    final row = idx ~/ 7;
    return Rect.fromLTWH(col * cs, row * cs, cs, cs);
  }

  List<List<int>> _rowSegments(List<int> days, double cs) {
    final segments = <List<int>>[];
    var current = <int>[];
    int? currentRow;
    for (final d in days) {
      final row = _cellRect(d, cs).top ~/ cs;
      if (current.isEmpty || row == currentRow) {
        current.add(d);
        currentRow = row;
      } else {
        segments.add(current);
        current = <int>[d];
        currentRow = row;
      }
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }

  bool _hitStreakDot(Offset pos, double cs) {
    final streaks = widget.habitStreaks ?? const <MonthHabitStreak>[];
    for (final streak in streaks) {
      final sorted = streak.doneDays.toList()..sort();
      final groups = <List<int>>[];
      var current = <int>[];
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
        for (final seg in _rowSegments(g, cs)) {
          for (final d in seg) {
            final r = _cellRect(d, cs);
            final y = r.center.dy + cs * 0.15;
            final dotRect = Rect.fromCenter(
              center: Offset(r.center.dx, y),
              width: cs * 0.25,
              height: cs * 0.25,
            );
            if (dotRect.contains(pos)) return true;
          }
        }
      }
    }
    return false;
  }

  String? _hitStreakHabit(Offset pos, double cs) {
    final streaks = widget.habitStreaks ?? const <MonthHabitStreak>[];
    for (final streak in streaks) {
      final sorted = streak.doneDays.toList()..sort();
      final groups = <List<int>>[];
      var current = <int>[];
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
        for (final seg in _rowSegments(g, cs)) {
          for (final d in seg) {
            final r = _cellRect(d, cs);
            final y = r.center.dy + cs * 0.15;
            final dotRect = Rect.fromCenter(
              center: Offset(r.center.dx, y),
              width: cs * 0.25,
              height: cs * 0.25,
            );
            if (dotRect.contains(pos)) return streak.habitId;
          }
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scheduleCulled();
  }

  @override
  void didUpdateWidget(covariant MonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleCulled();
  }

  @override
  Widget build(BuildContext context) {
    final cs = _cellSize(context);
    final days = _daysInMonth();
    final offset = _firstWeekdayOffset();
    final rows = ((offset + days) / 7).ceil();
    final size = Size(cs * 7, cs * rows);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    _scheduleCulled();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final col = (details.localPosition.dx / cs).floor().clamp(0, 6);
        final row = (details.localPosition.dy / cs).floor();
        final idx = row * 7 + col - offset;
        final day = idx + 1;
        if (day >= 1 && day <= days) {
          if (_hitStreakDot(details.localPosition, cs)) {
            final habitId = _hitStreakHabit(details.localPosition, cs);
            if (habitId != null) {
              widget.onHabitTap?.call(habitId);
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
          onCulledCount: null,
          daySemanticsLabel: widget.daySemanticsLabel,
          streakSemanticsLabel: widget.streakSemanticsLabel,
          onDateTap: widget.onDateTap,
          onHabitTap: widget.onHabitTap,
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
    required this.daySemanticsLabel,
    required this.streakSemanticsLabel,
    this.onDateTap,
    this.onHabitTap,
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
  final String Function(int day, int count) daySemanticsLabel;
  final String Function(MonthHabitStreak streak) streakSemanticsLabel;
  final void Function(DateTime date)? onDateTap;
  final void Function(String habitId)? onHabitTap;

  bool _visible(int day) {
    if (visibleStartDay != null && day < visibleStartDay!) return false;
    if (visibleEndDay != null && day > visibleEndDay!) return false;
    return true;
  }

  List<List<int>> _rowSegments(List<int> days) {
    final segments = <List<int>>[];
    var current = <int>[];
    int? currentRow;
    for (final d in days) {
      final idx = firstOffset + (d - 1);
      final row = idx ~/ 7;
      if (current.isEmpty || row == currentRow) {
        current.add(d);
        currentRow = row;
      } else {
        segments.add(current);
        current = <int>[d];
        currentRow = row;
      }
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }

  Rect _cellRect(int day) {
    final idx = firstOffset + (day - 1);
    final col = idx % 7;
    final row = idx ~/ 7;
    return Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var day = 1; day <= daysInMonth; day++) {
      if (!_visible(day)) continue;
      final rect = _cellRect(day);
      final density = densityOf(day);
      final count = countOf(day);
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
      final countFontSize = math.min(10.0 * textScale, cellSize * 0.4);
      final tp = TextPainter(
        text: TextSpan(
          text: '$count',
          style: TextStyle(fontSize: countFontSize),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '\u2026',
      );
      tp.layout(maxWidth: rect.width - 2);
      tp.paint(canvas, Offset(rect.left + 2, rect.top + 2));
    }
    for (final streak in habitStreaks) {
      final sorted = streak.doneDays.toList()..sort();
      final groups = <List<int>>[];
      var current = <int>[];
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
        for (final seg in _rowSegments(g)) {
          if (seg.isEmpty) continue;
          final startRect = _cellRect(seg.first);
          final endRect = _cellRect(seg.last);
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
          for (final d in seg) {
            final r = _cellRect(d);
            canvas.drawCircle(
              Offset(r.center.dx, y),
              2.5,
              paint..color = Color(streak.colorArgb),
            );
          }
        }
      }
    }
    if (onCulledCount != null) {
      var culled = 0;
      for (var day = 1; day <= daysInMonth; day++) {
        if (!_visible(day)) culled++;
      }
      onCulledCount!.call(culled);
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    final result = <CustomPainterSemantics>[];
    for (var day = 1; day <= daysInMonth; day++) {
      if (!_visible(day)) continue;
      final rect = _cellRect(day);
      final count = countOf(day);
      final label = daySemanticsLabel(day, count);
      result.add(
        CustomPainterSemantics(
          rect: rect,
          properties: SemanticsProperties(
            label: label,
            textDirection: TextDirection.ltr,
            onTap: onDateTap != null
                ? () => onDateTap!(DateTime(month.year, month.month, day))
                : null,
          ),
        ),
      );
    }
    for (final streak in habitStreaks) {
      final sorted = streak.doneDays.toList()..sort();
      final groups = <List<int>>[];
      var current = <int>[];
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
        for (final seg in _rowSegments(g)) {
          if (seg.isEmpty) continue;
          final startRect = _cellRect(seg.first);
          final endRect = _cellRect(seg.last);
          final y =
              (startRect.center.dy + endRect.center.dy) / 2 + cellSize * 0.15;
          result.add(
            CustomPainterSemantics(
              rect: Rect.fromLTWH(
                startRect.left,
                y - 4,
                endRect.right - startRect.left,
                8,
              ),
              properties: SemanticsProperties(
                label: streakSemanticsLabel(streak),
                textDirection: TextDirection.ltr,
                onTap: onHabitTap != null
                    ? () => onHabitTap!(streak.habitId)
                    : null,
              ),
            ),
          );
        }
      }
    }
    return result;
  };

  @override
  bool shouldRepaint(covariant _MonthPainter oldDelegate) => true;
}
