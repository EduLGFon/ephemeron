import 'package:material_ui/material_ui.dart';

import '../../application/stream_day_mark.dart';
import '../../engine/stream_time_viewport.dart';
import 'day_canvas_painter.dart';
import 'day_canvas_style.dart';

class DayCanvas extends StatefulWidget {
  const DayCanvas({
    super.key,
    required this.viewport,
    required this.marks,
    required this.timeFormatter,
    this.onMarkTap,
    this.onCulledCount,
    this.onPaint,
  });

  final StreamTimeViewport viewport;
  final List<StreamDayMark> marks;
  final String Function(int epochMs) timeFormatter;
  final void Function(StreamDayMark mark)? onMarkTap;
  final void Function(int culledCount)? onCulledCount;
  final void Function()? onPaint;

  @override
  State<DayCanvas> createState() => _DayCanvasState();
}

class _DayCanvasState extends State<DayCanvas> {
  late List<StreamDayMark> _sorted;
  late List<int> _starts;
  late List<int> _ends;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant DayCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.marks, widget.marks)) {
      _prepare();
    }
  }

  void _prepare() {
    _sorted = List<StreamDayMark>.from(widget.marks)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    _starts = _sorted.map((m) => m.startMs).toList(growable: false);
    _ends = _sorted.map((m) => m.endMs).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = DayCanvasStyle.fromColorScheme(scheme);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          widget.viewport.setViewportHeight(constraints.maxHeight);
          return CustomPaint(
            painter: DayCanvasPainter(
              viewport: widget.viewport,
              marks: _sorted,
              starts: _starts,
              ends: _ends,
              timeFormatter: widget.timeFormatter,
              textScale: textScale,
              style: style,
              onCulledCount: widget.onCulledCount,
              onPaint: widget.onPaint,
            ),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          );
        },
      ),
    );
  }
}
