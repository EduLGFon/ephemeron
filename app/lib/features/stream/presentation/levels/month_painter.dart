part of 'month_view.dart';

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
  final String Function(int day, int count) daySemanticsLabel;
  final String Function(MonthHabitStreak streak, int firstDay, int lastDay)
  streakSemanticsLabel;
  final void Function(DateTime date)? onDateTap;
  final void Function(String habitId)? onHabitTap;

  bool _visible(int day) {
    if (visibleStartDay != null && day < visibleStartDay!) return false;
    if (visibleEndDay != null && day > visibleEndDay!) return false;
    return true;
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
      final groups = monthHabitStreakGroups(streak.doneDays);
      for (final g in groups) {
        if (g.isEmpty) continue;
        for (final seg in monthHabitStreakRowSegments(g, firstOffset)) {
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
      final groups = monthHabitStreakGroups(streak.doneDays);
      for (final g in groups) {
        if (g.isEmpty) continue;
        final segs = monthHabitStreakRowSegments(g, firstOffset);
        for (var si = 0; si < segs.length; si++) {
          final seg = segs[si];
          if (seg.isEmpty) continue;
          final startRect = _cellRect(seg.first);
          final endRect = _cellRect(seg.last);
          final y =
              (startRect.center.dy + endRect.center.dy) / 2 + cellSize * 0.15;
          final label = streakSemanticsLabel(streak, seg.first, seg.last);
          result.add(
            CustomPainterSemantics(
              rect: Rect.fromLTWH(
                startRect.left,
                y - 4,
                endRect.right - startRect.left,
                8,
              ),
              properties: SemanticsProperties(
                label: label,
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
