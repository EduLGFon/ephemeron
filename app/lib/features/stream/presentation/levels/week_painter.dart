part of 'week_view.dart';

class _WeekPainter extends CustomPainter {
  _WeekPainter({
    required this.weekStart,
    required this.buckets,
    required this.cellWidth,
    required this.height,
    required this.textScale,
    required this.dayHeaderBuilder,
    required this.daySemanticsLabel,
    required this.habitRows,
    required this.maxChips,
    this.overflowLabelBuilder,
    required this.dayVisible,
    required this.markSemanticsLabel,
    this.onDayTap,
    this.onCompleteMark,
    this.onPushMark,
    this.onRescheduleMark,
    this.onDeleteMark,
    required this.markActionLabels,
  });

  final DateTime weekStart;
  final List<List<StreamDayMark>> buckets;
  final double cellWidth;
  final double height;
  final double textScale;
  final String Function(int, DateTime) dayHeaderBuilder;
  final String Function(int, [DateTime?]) daySemanticsLabel;
  final List<WeekHabitDotRow> habitRows;
  final int maxChips;
  final String Function(int)? overflowLabelBuilder;
  final bool Function(int) dayVisible;
  final String Function(StreamDayMark) markSemanticsLabel;
  final void Function(DateTime)? onDayTap;
  final void Function(String)? onCompleteMark;
  final void Function(String)? onPushMark;
  final void Function(String)? onRescheduleMark;
  final void Function(String)? onDeleteMark;
  final Map<String, String> markActionLabels;

  double get _headerH => 20.0 * textScale;
  double get _chipH => 14.0 * textScale;
  double get _gap => 2.0 * textScale;

  String _header(int i) =>
      dayHeaderBuilder(i, weekStart.add(Duration(days: i)));

  String _daySemantics(int i) =>
      daySemanticsLabel(i, weekStart.add(Duration(days: i)));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var day = 0; day < 7; day++) {
      if (!dayVisible(day)) continue;
      final x = day * cellWidth;
      final tp = TextPainter(
        text: TextSpan(
          text: _header(day),
          style: TextStyle(
            fontSize: 11 * textScale,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '\u2026',
      );
      tp.layout(maxWidth: cellWidth);
      tp.paint(canvas, Offset(x + 2, 2));
      final bucket = buckets[day];
      final shown = math.min(maxChips, bucket.length);
      for (var ci = 0; ci < shown; ci++) {
        final m = bucket[ci];
        final rect = Rect.fromLTWH(
          x + 2,
          _headerH + 4 * textScale + ci * (_chipH + _gap),
          cellWidth - 4,
          _chipH,
        );
        paint.color = Color(m.colorArgb);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          paint,
        );
      }
      if (bucket.length > maxChips) {
        final remaining = bucket.length - maxChips;
        final label = overflowLabelBuilder != null
            ? overflowLabelBuilder!(remaining)
            : '+$remaining';
        final oTp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(fontSize: 10 * textScale),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        oTp.layout(maxWidth: cellWidth - 4);
        oTp.paint(
          canvas,
          Offset(x + 2, _headerH + 4 * textScale + shown * (_chipH + _gap)),
        );
      }
    }
    var hy = height - ((habitRows.length) * 12.0 * textScale);
    if (hy < _headerH + 4 * textScale) hy = _headerH + 4 * textScale;
    for (final row in habitRows) {
      for (var day = 0; day < 7; day++) {
        if (!dayVisible(day)) continue;
        final done = day < row.done.length && row.done[day];
        final cx = day * cellWidth + cellWidth / 2;
        final cy = hy + 5 * textScale;
        paint.color = done ? const Color(0xFF4CAF50) : const Color(0xFFBDBDBD);
        canvas.drawCircle(Offset(cx, cy), 3 * textScale, paint);
      }
      hy += 12.0 * textScale;
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    final result = <CustomPainterSemantics>[];
    for (var day = 0; day < 7; day++) {
      if (!dayVisible(day)) continue;
      final x = day * cellWidth;
      final date = weekStart.add(Duration(days: day));
      result.add(
        CustomPainterSemantics(
          rect: Rect.fromLTWH(x, 0, cellWidth, height),
          properties: SemanticsProperties(
            label: _daySemantics(day),
            textDirection: TextDirection.ltr,
            onTap: onDayTap != null ? () => onDayTap!(date) : null,
          ),
        ),
      );
    }
    return result;
  };

  @override
  bool shouldRepaint(covariant _WeekPainter oldDelegate) => true;
}
