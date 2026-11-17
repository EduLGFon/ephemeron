part of 'month_view.dart';

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

  bool _hitStreakDot(Offset pos, double cs) {
    final streaks = widget.habitStreaks ?? const <MonthHabitStreak>[];
    for (final streak in streaks) {
      final groups = monthHabitStreakGroups(streak.doneDays);
      for (final g in groups) {
        for (final seg in monthHabitStreakRowSegments(
          g,
          _firstWeekdayOffset(),
        )) {
          for (final d in seg) {
            final r = _cellRect(d, cs);
            final y = r.center.dy + cs * 0.15;
            // Painted dot radius is 2.5; hit area is at least the painted
            // dot plus slop: max(paintedRadius * 1.5, 6 dp).
            const paintedRadius = 2.5;
            final hitRadius = math.max(paintedRadius * 1.5, 6.0);
            final dotRect = Rect.fromCenter(
              center: Offset(r.center.dx, y),
              width: hitRadius * 2,
              height: hitRadius * 2,
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
      final groups = monthHabitStreakGroups(streak.doneDays);
      for (final g in groups) {
        for (final seg in monthHabitStreakRowSegments(
          g,
          _firstWeekdayOffset(),
        )) {
          for (final d in seg) {
            final r = _cellRect(d, cs);
            final y = r.center.dy + cs * 0.15;
            // Painted dot radius is 2.5; hit area is at least the painted
            // dot plus slop: max(paintedRadius * 1.5, 6 dp).
            const paintedRadius = 2.5;
            final hitRadius = math.max(paintedRadius * 1.5, 6.0);
            final dotRect = Rect.fromCenter(
              center: Offset(r.center.dx, y),
              width: hitRadius * 2,
              height: hitRadius * 2,
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
          if (widget.onHabitTap != null &&
              _hitStreakDot(details.localPosition, cs)) {
            final habitId = _hitStreakHabit(details.localPosition, cs);
            if (habitId != null) {
              widget.onHabitTap!(habitId);
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
