part of 'year_view.dart';

class _YearViewState extends State<YearView> {
  int? _lastCulled;

  void _scheduleCulled(int value) {
    if (value == _lastCulled) return;
    _lastCulled = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCulledCount?.call(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = yearVisibleMonths(
      startMonth: widget.visibleMonthStart,
      endMonth: widget.visibleMonthEnd,
    );
    _scheduleCulled(12 - visible.length);
    final emptyLabel = widget.emptyLabel;
    if (emptyLabel != null &&
        !yearHasData(
          year: widget.year,
          dayCounts: widget.dayCounts,
          habitStreaks: widget.habitStreaks,
        )) {
      return _YearEmpty(label: emptyLabel);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : 320.0;
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final geometry = buildYearViewGeometry(
          year: widget.year,
          width: width,
          textScale: textScale,
          dayCounts: widget.dayCounts,
          habitStreaks: widget.habitStreaks,
          firstDayOfWeek: widget.firstDayOfWeek,
          monthColumns: widget.monthColumns,
          visibleMonthStart: widget.visibleMonthStart,
          visibleMonthEnd: widget.visibleMonthEnd,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details.localPosition, geometry),
          child: CustomPaint(
            size: geometry.size,
            painter: _YearPainter(
              geometry: geometry,
              textScale: textScale,
              monthHeading: widget.monthHeading,
              monthSemanticsLabel: widget.monthSemanticsLabel,
              daySemanticsLabel: widget.daySemanticsLabel,
              habitStreakSemanticsLabel: widget.habitStreakSemanticsLabel,
              colors: Theme.of(context).colorScheme,
              onDateTap: widget.onDateTap,
              onHabitTap: widget.onHabitTap,
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset position, YearViewGeometry geometry) {
    for (final month in geometry.months) {
      if (widget.onHabitTap != null) {
        for (final streak in month.streaks) {
          if (streak.rect.contains(position)) {
            widget.onHabitTap!(streak.habit.habitId);
            return;
          }
        }
      }
      if (!month.rect.contains(position)) continue;
      for (final day in month.days) {
        if (day.rect.contains(position)) {
          widget.onDateTap?.call(day.date);
          return;
        }
      }
      widget.onDateTap?.call(DateTime(geometry.year, month.month, 1));
      return;
    }
  }
}

class _YearEmpty extends StatelessWidget {
  const _YearEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
