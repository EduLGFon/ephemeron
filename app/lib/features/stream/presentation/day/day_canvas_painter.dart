import 'package:flutter/rendering.dart';

import '../../application/stream_day_mark.dart';
import '../../engine/mark_culler.dart';
import '../../engine/stream_mark_layout.dart';
import '../../engine/stream_time_viewport.dart';
import 'day_canvas_style.dart';

class DayCanvasPainter extends CustomPainter {
  DayCanvasPainter({
    required this.viewport,
    required this.marks,
    required this.starts,
    required this.ends,
    required this.timeFormatter,
    required this.textScale,
    required this.style,
    this.onCulledCount,
    this.onPaint,
  }) : super(repaint: viewport);

  final StreamTimeViewport viewport;
  final List<StreamDayMark> marks;
  final List<int> starts;
  final List<int> ends;
  final String Function(int epochMs) timeFormatter;
  final double textScale;
  final DayCanvasStyle style;
  final void Function(int culledCount)? onCulledCount;
  final void Function()? onPaint;

  static const double _minBlockPx = 2.0;
  static const double _barWidth = 3.0;

  _CulledMarks _cull(Size size) {
    final t0 = viewport.pxToTime(0);
    final t1 = viewport.pxToTime(size.height);
    final range = cullMarks(starts, ends, t0, t1);
    final visible = marks.sublist(range.start, range.end);
    final intervals = visible
        .map((m) => MarkInterval(startMs: m.startMs, endMs: m.endMs, id: m.id))
        .toList(growable: false);
    final layout = layoutMarkColumns(intervals);
    return _CulledMarks(visible: visible, layout: layout, t0: t0, t1: t1);
  }

  Rect _blockRect(StreamDayMark m, MarkLayout l, Size size) {
    var top = viewport.timeToPx(m.startMs);
    var bottom = viewport.timeToPx(m.endMs);
    if (bottom - top < _minBlockPx) bottom = top + _minBlockPx;
    return markColumnRect(
      column: l.column,
      columnCount: l.columnCount,
      canvasWidth: size.width,
      top: top,
      bottom: bottom,
    );
  }

  void _paintHairlines(Canvas canvas, Size size, int t0, int t1) {
    final hairline = Paint()
      ..color = style.hairline
      ..strokeWidth = 1;
    var cursor = (t0 ~/ (60 * 60 * 1000)) * (60 * 60 * 1000);
    while (cursor <= t1) {
      final y = viewport.timeToPx(cursor);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hairline);
      cursor += 60 * 60 * 1000;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    onPaint?.call();
    final culled = _cull(size);
    onCulledCount?.call(culled.visible.length);
    _paintHairlines(canvas, size, culled.t0, culled.t1);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    for (var i = 0; i < culled.visible.length; i++) {
      final m = culled.visible[i];
      final l = culled.layout[i];
      final rect = _blockRect(m, l, size);
      final color = Color(m.colorArgb);
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: style.blockFillAlpha),
      );
      canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.top, rect.left + _barWidth, rect.bottom),
        Paint()..color = color,
      );

      textPainter.text = TextSpan(
        text: m.title,
        style: TextStyle(color: style.title, fontSize: 12 * textScale),
      );
      textPainter.layout(
        maxWidth: (rect.width - 4).clamp(0.0, double.infinity),
      );
      textPainter.paint(canvas, Offset(rect.left + 2, rect.top + 2));

      if (rect.bottom - rect.top > 28 * textScale) {
        textPainter.text = TextSpan(
          text: timeFormatter(m.startMs),
          style: TextStyle(color: style.subtitle, fontSize: 10 * textScale),
        );
        textPainter.layout(
          maxWidth: (rect.width - 4).clamp(0.0, double.infinity),
        );
        textPainter.paint(
          canvas,
          Offset(rect.left + 2, rect.top + 2 + 14 * textScale),
        );
      }
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    final culled = _cull(size);
    final result = <CustomPainterSemantics>[];
    for (var i = 0; i < culled.visible.length; i++) {
      final m = culled.visible[i];
      final l = culled.layout[i];
      final rect = _blockRect(m, l, size);
      if (rect.width <= 0) continue;
      result.add(
        CustomPainterSemantics(
          rect: rect,
          properties: SemanticsProperties(
            label: '${m.title}, ${timeFormatter(m.startMs)}',
            textDirection: TextDirection.ltr,
          ),
        ),
      );
    }
    return result;
  };

  @override
  bool shouldRepaint(covariant DayCanvasPainter oldDelegate) {
    return oldDelegate.viewport != viewport ||
        !identical(oldDelegate.marks, marks) ||
        oldDelegate.textScale != textScale ||
        oldDelegate.style != style ||
        oldDelegate.timeFormatter != timeFormatter;
  }
}

class _CulledMarks {
  const _CulledMarks({
    required this.visible,
    required this.layout,
    required this.t0,
    required this.t1,
  });
  final List<StreamDayMark> visible;
  final List<MarkLayout> layout;
  final int t0;
  final int t1;
}
