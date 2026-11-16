import 'package:material_ui/material_ui.dart';

import '../../application/stream_day_mark.dart';
import '../../engine/mark_culler.dart';
import '../../engine/stream_time_viewport.dart';

typedef TimeLabelFormatter = String Function(int epochMs);

class DayCanvas extends StatefulWidget {
  const DayCanvas({
    super.key,
    required this.viewport,
    required this.marks,
    required this.timeFormatter,
    this.onMarkTap,
    this.onCulledCount,
  });

  final StreamTimeViewport viewport;
  final List<StreamDayMark> marks;
  final TimeLabelFormatter timeFormatter;
  final void Function(StreamDayMark mark)? onMarkTap;
  final void Function(int culledCount)? onCulledCount;

  @override
  State<DayCanvas> createState() => _DayCanvasState();
}

class _DayCanvasState extends State<DayCanvas> {
  late List<StreamDayMark> _sorted;
  late List<int> _starts;
  late List<int> _ends;

  @override
  void didUpdateWidget(covariant DayCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepare();
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    _sorted = List<StreamDayMark>.from(widget.marks)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    _starts = _sorted.map((m) => m.startMs).toList(growable: false);
    _ends = _sorted.map((m) => m.endMs).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return RepaintBoundary(
      child: CustomPaint(
        painter: DayCanvasPainter(
          viewport: widget.viewport,
          marks: _sorted,
          starts: _starts,
          ends: _ends,
          timeFormatter: widget.timeFormatter,
          textScale: textScale,
          onCulledCount: widget.onCulledCount,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class DayCanvasPainter extends CustomPainter {
  DayCanvasPainter({
    required this.viewport,
    required this.marks,
    required this.starts,
    required this.ends,
    required this.timeFormatter,
    required this.textScale,
    this.onCulledCount,
  }) : super(repaint: viewport);

  final StreamTimeViewport viewport;
  final List<StreamDayMark> marks;
  final List<int> starts;
  final List<int> ends;
  final TimeLabelFormatter timeFormatter;
  final double textScale;
  final void Function(int culledCount)? onCulledCount;

  static const double _minBlockPx = 2.0;
  static const double _barWidth = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    viewport.setViewportHeight(size.height);
    final t0 = viewport.pxToTime(0);
    final t1 = viewport.pxToTime(size.height);
    final range = cullMarks(starts, ends, t0, t1);
    onCulledCount?.call(range.end - range.start);

    // Hour hairlines.
    final hairline = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    final firstHour = DateTime.fromMillisecondsSinceEpoch(t0)
        .copyWith(minute: 0, second: 0, millisecond: 0);
    var cursor = firstHour.millisecondsSinceEpoch;
    while (cursor <= t1) {
      final y = viewport.timeToPx(cursor);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hairline);
      cursor += 60 * 60 * 1000;
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    for (var i = range.start; i < range.end; i++) {
      final m = marks[i];
      var top = viewport.timeToPx(m.startMs);
      var bottom = viewport.timeToPx(m.endMs);
      if (bottom - top < _minBlockPx) bottom = top + _minBlockPx;
      final rect = Rect.fromLTRB(_barWidth + 4, top, size.width - 4, bottom);
      final color = Color(m.colorArgb);
      final fill = Paint()..color = color.withValues(alpha: 0.18);
      canvas.drawRect(rect, fill);
      // 3dp colour bar.
      canvas.drawRect(
        Rect.fromLTRB(4, top, 4 + _barWidth, bottom),
        Paint()..color = color,
      );

      final blockHeight = bottom - top;
      // Title.
      textPainter.text = TextSpan(
        text: m.title,
        style: TextStyle(
          color: const Color(0xFF222222),
          fontSize: 12 * textScale,
        ),
      );
      textPainter.layout(maxWidth: rect.width - 4);
      textPainter.paint(canvas, Offset(rect.left + 2, top + 2));

      // Time label only when block tall enough.
      if (blockHeight > 28 * textScale) {
        textPainter.text = TextSpan(
          text: timeFormatter(m.startMs),
          style: TextStyle(
            color: const Color(0xFF555555),
            fontSize: 10 * textScale,
          ),
        );
        textPainter.layout(maxWidth: rect.width - 4);
        textPainter.paint(
          canvas,
          Offset(rect.left + 2, top + 2 + 14 * textScale),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant DayCanvasPainter oldDelegate) => true;
}
