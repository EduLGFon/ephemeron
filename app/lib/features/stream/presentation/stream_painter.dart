import 'package:material_ui/material_ui.dart';

import '../engine/time_viewport.dart';
import '../engine/mark_culler.dart';
import '../data/fake_marks.dart';

class StreamPainter extends CustomPainter {
  StreamPainter({
    required this.viewport,
    required this.marks,
    required this.starts,
    required this.ends,
  }) : super(repaint: viewport);

  final TimeViewport viewport;
  final List<StreamMark> marks;
  final List<int> starts;
  final List<int> ends;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    viewport.setViewportHeight(h);
    final t0 = viewport.pxToTime(0);
    final t1 = viewport.pxToTime(h);
    final range = cullMarks(starts, ends, t0, t1);
    final paint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    for (var i = range.start; i < range.end; i++) {
      final m = marks[i];
      final top = viewport.timeToPx(m.startMs);
      final bottom = viewport.timeToPx(m.endMs);
      final rect = Rect.fromLTRB(
        8,
        top,
        size.width - 8,
        bottom < top + 2 ? top + 2 : bottom,
      );
      paint.color = Color(m.color);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );
      if (rect.height > 14) {
        textPainter.text = TextSpan(
          text: m.title,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        );
        textPainter.layout(maxWidth: rect.width - 4);
        textPainter.paint(canvas, Offset(rect.left + 2, rect.top + 1));
      }
    }
  }

  @override
  bool shouldRepaint(covariant StreamPainter oldDelegate) => true;
}
