part of 'year_view_layout.dart';

YearMonthGeometry _monthGeometry({
  required int year,
  required int month,
  required int columns,
  required _YearMetrics metrics,
  required Map<String, int> dayCounts,
  required List<YearHabitStreak> habitStreaks,
  required int firstDayOfWeek,
}) {
  final data = buildYearMonthData(
    year: year,
    month: month,
    dayCounts: dayCounts,
    firstDayOfWeek: firstDayOfWeek,
  );
  final rects = _monthRects(month: month, columns: columns, metrics: metrics);
  return YearMonthGeometry(
    month: month,
    rect: rects.rect,
    headerRect: rects.headerRect,
    gridRect: rects.gridRect,
    cellSize: metrics.cellSize,
    totalCount: data.totalCount,
    days: _dayGeometries(data, rects.gridRect, metrics.cellSize),
    streaks: _streakGeometries(
      year: year,
      month: month,
      data: data,
      gridRect: rects.gridRect,
      cellSize: metrics.cellSize,
      habitStreaks: habitStreaks,
      firstDayOfWeek: firstDayOfWeek,
    ),
  );
}

({Rect rect, Rect headerRect, Rect gridRect}) _monthRects({
  required int month,
  required int columns,
  required _YearMetrics metrics,
}) {
  final slot = month - 1;
  final row = slot ~/ columns - metrics.firstRow;
  final column = slot % columns;
  final left = _outerPadding + column * (metrics.blockWidth + _columnGap);
  final top = _outerPadding + row * (metrics.blockHeight + _rowGap);
  final rect = Rect.fromLTWH(
    left,
    top,
    metrics.blockWidth,
    metrics.blockHeight,
  );
  final headerRect = Rect.fromLTWH(
    left + _innerPadding,
    top + _innerPadding,
    metrics.gridWidth,
    metrics.headerHeight,
  );
  final gridRect = Rect.fromLTWH(
    left + _innerPadding,
    headerRect.bottom + _headerGap,
    metrics.gridWidth,
    metrics.cellSize * _maxWeekRows,
  );
  return (rect: rect, headerRect: headerRect, gridRect: gridRect);
}

List<YearDayGeometry> _dayGeometries(
  YearMonthData data,
  Rect gridRect,
  double cellSize,
) {
  final days = <YearDayGeometry>[];
  for (final day in data.days) {
    final index = data.firstWeekdayOffset + day.date.day - 1;
    days.add(
      YearDayGeometry(
        date: day.date,
        count: day.count,
        density: day.density,
        rect: Rect.fromLTWH(
          gridRect.left + (index % 7) * cellSize,
          gridRect.top + (index ~/ 7) * cellSize,
          cellSize,
          cellSize,
        ),
      ),
    );
  }
  return days;
}

List<YearStreakGeometry> _streakGeometries({
  required int year,
  required int month,
  required YearMonthData data,
  required Rect gridRect,
  required double cellSize,
  required List<YearHabitStreak> habitStreaks,
  required int firstDayOfWeek,
}) {
  final result = <YearStreakGeometry>[];
  for (var habitIndex = 0; habitIndex < habitStreaks.length; habitIndex++) {
    final habit = habitStreaks[habitIndex];
    final runs = yearStreakRunsForMonth(
      year: year,
      month: month,
      streak: habit,
      firstDayOfWeek: firstDayOfWeek,
    );
    for (final run in runs) {
      result.add(
        _streakGeometry(
          habit: habit,
          run: run,
          data: data,
          gridRect: gridRect,
          cellSize: cellSize,
          habitIndex: habitIndex,
          habitCount: habitStreaks.length,
        ),
      );
    }
  }
  return result;
}

YearStreakGeometry _streakGeometry({
  required YearHabitStreak habit,
  required YearStreakRun run,
  required YearMonthData data,
  required Rect gridRect,
  required double cellSize,
  required int habitIndex,
  required int habitCount,
}) {
  final firstIndex = data.firstWeekdayOffset + run.firstDay - 1;
  final lastIndex = data.firstWeekdayOffset + run.lastDay - 1;
  final y =
      gridRect.top +
      (run.row + 0.5 + _habitOffset(habitIndex, habitCount)) * cellSize;
  final start = Offset(
    gridRect.left + (firstIndex % 7) * cellSize + cellSize / 2,
    y,
  );
  final end = Offset(
    gridRect.left + (lastIndex % 7) * cellSize + cellSize / 2,
    y,
  );
  final halfHeight = math.max(6.0, cellSize * 0.4);
  return YearStreakGeometry(
    habit: habit,
    firstDay: run.firstDay,
    lastDay: run.lastDay,
    start: start,
    end: end,
    rect: Rect.fromLTRB(
      math.min(start.dx, end.dx) - 2,
      y - halfHeight,
      math.max(start.dx, end.dx) + 2,
      y + halfHeight,
    ),
  );
}

double _habitOffset(int index, int count) {
  if (count <= 1) return 0;
  return (index / (count - 1) - 0.5) * _streakSpread;
}
