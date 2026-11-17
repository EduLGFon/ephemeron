part of 'year_view.dart';

List<CustomPainterSemantics> _buildYearSemantics({
  required YearViewGeometry geometry,
  required String Function(int month) monthHeading,
  required String Function(String heading, int count) monthSemanticsLabel,
  required String Function(DateTime date, int count) daySemanticsLabel,
  required String Function(
    YearHabitStreak streak,
    DateTime first,
    DateTime last,
  )
  habitStreakSemanticsLabel,
  required void Function(DateTime date)? onDateTap,
  required void Function(String habitId)? onHabitTap,
}) {
  final result = <CustomPainterSemantics>[];
  for (final month in geometry.months) {
    result.add(
      _monthSemantics(
        geometry: geometry,
        month: month,
        heading: monthHeading(month.month),
        monthSemanticsLabel: monthSemanticsLabel,
        onDateTap: onDateTap,
      ),
    );
    for (final day in month.days) {
      result.add(
        _daySemantics(
          day: day,
          daySemanticsLabel: daySemanticsLabel,
          onDateTap: onDateTap,
        ),
      );
    }
    for (final streak in month.streaks) {
      result.add(
        _streakSemantics(
          geometry: geometry,
          month: month,
          streak: streak,
          habitStreakSemanticsLabel: habitStreakSemanticsLabel,
          onHabitTap: onHabitTap,
        ),
      );
    }
  }
  return result;
}

CustomPainterSemantics _monthSemantics({
  required YearViewGeometry geometry,
  required YearMonthGeometry month,
  required String heading,
  required String Function(String heading, int count) monthSemanticsLabel,
  required void Function(DateTime date)? onDateTap,
}) {
  return CustomPainterSemantics(
    rect: month.headerRect,
    properties: SemanticsProperties(
      label: monthSemanticsLabel(heading, month.totalCount),
      textDirection: TextDirection.ltr,
      onTap: onDateTap == null
          ? null
          : () => onDateTap(DateTime(geometry.year, month.month, 1)),
    ),
  );
}

CustomPainterSemantics _daySemantics({
  required YearDayGeometry day,
  required String Function(DateTime date, int count) daySemanticsLabel,
  required void Function(DateTime date)? onDateTap,
}) {
  return CustomPainterSemantics(
    rect: day.rect,
    properties: SemanticsProperties(
      label: daySemanticsLabel(day.date, day.count),
      textDirection: TextDirection.ltr,
      onTap: onDateTap == null ? null : () => onDateTap(day.date),
    ),
  );
}

CustomPainterSemantics _streakSemantics({
  required YearViewGeometry geometry,
  required YearMonthGeometry month,
  required YearStreakGeometry streak,
  required String Function(
    YearHabitStreak streak,
    DateTime first,
    DateTime last,
  )
  habitStreakSemanticsLabel,
  required void Function(String habitId)? onHabitTap,
}) {
  return CustomPainterSemantics(
    rect: streak.rect,
    properties: SemanticsProperties(
      label: habitStreakSemanticsLabel(
        streak.habit,
        DateTime(geometry.year, month.month, streak.firstDay),
        DateTime(geometry.year, month.month, streak.lastDay),
      ),
      textDirection: TextDirection.ltr,
      onTap: onHabitTap == null ? null : () => onHabitTap(streak.habit.habitId),
    ),
  );
}
