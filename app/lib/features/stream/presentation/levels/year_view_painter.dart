part of 'year_view.dart';

class _YearPainter extends CustomPainter {
  _YearPainter({
    required this.geometry,
    required this.textScale,
    required this.monthHeading,
    required this.monthSemanticsLabel,
    required this.daySemanticsLabel,
    required this.habitStreakSemanticsLabel,
    required this.colors,
    this.onDateTap,
    this.onHabitTap,
  });

  final YearViewGeometry geometry;
  final double textScale;
  final String Function(int month) monthHeading;
  final String Function(String heading, int count) monthSemanticsLabel;
  final String Function(DateTime date, int count) daySemanticsLabel;
  final String Function(YearHabitStreak streak, DateTime first, DateTime last)
  habitStreakSemanticsLabel;
  final ColorScheme colors;
  final void Function(DateTime date)? onDateTap;
  final void Function(String habitId)? onHabitTap;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colors.outlineVariant;
    for (final month in geometry.months) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(month.rect, const Radius.circular(8)),
        outline,
      );
      _paintHeader(canvas, month);
      _paintDays(canvas, month);
      _paintStreaks(canvas, month);
    }
  }

  void _paintHeader(Canvas canvas, YearMonthGeometry month) {
    final countPainter = TextPainter(
      text: TextSpan(
        text: '${month.totalCount}',
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 10 * textScale,
          fontWeight: FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '\u2026',
    );
    countPainter.layout(maxWidth: month.headerRect.width * 0.5);
    final countLeft = month.headerRect.right - countPainter.width;
    countPainter.paint(
      canvas,
      Offset(
        countLeft,
        month.headerRect.top +
            (month.headerRect.height - countPainter.height) / 2,
      ),
    );

    final headingPainter = TextPainter(
      text: TextSpan(
        text: monthHeading(month.month),
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 11 * textScale,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '\u2026',
    );
    headingPainter.layout(
      maxWidth: math.max(0.0, countLeft - month.headerRect.left - 4),
    );
    headingPainter.paint(
      canvas,
      Offset(
        month.headerRect.left,
        month.headerRect.top +
            (month.headerRect.height - headingPainter.height) / 2,
      ),
    );
  }

  void _paintDays(Canvas canvas, YearMonthGeometry month) {
    final paint = Paint()..style = PaintingStyle.fill;
    final inset = math.min(1.0, month.cellSize * 0.1);
    for (final day in month.days) {
      final rect = day.rect.deflate(inset);
      paint.color = day.count <= 0
          ? colors.outlineVariant.withValues(alpha: 0.35)
          : colors.primary.withValues(alpha: 0.16 + 0.72 * day.density);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.min(2.0, rect.shortestSide / 2)),
        ),
        paint,
      );
    }
  }

  void _paintStreaks(Canvas canvas, YearMonthGeometry month) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final streak in month.streaks) {
      paint
        ..color = Color(streak.habit.colorArgb)
        ..style = PaintingStyle.fill;
      if (streak.start == streak.end) {
        canvas.drawCircle(
          streak.start,
          math.max(1.2, month.cellSize * 0.12),
          paint,
        );
      } else {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, month.cellSize * 0.16);
        canvas.drawLine(streak.start, streak.end, paint);
      }
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    return _buildYearSemantics(
      geometry: geometry,
      monthHeading: monthHeading,
      monthSemanticsLabel: monthSemanticsLabel,
      daySemanticsLabel: daySemanticsLabel,
      habitStreakSemanticsLabel: habitStreakSemanticsLabel,
      onDateTap: onDateTap,
      onHabitTap: onHabitTap,
    );
  };

  @override
  bool shouldRepaint(covariant _YearPainter oldDelegate) => true;
}
