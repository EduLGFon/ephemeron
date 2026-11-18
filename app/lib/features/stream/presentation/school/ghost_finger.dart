import 'package:material_ui/material_ui.dart';

import 'gesture_school_step.dart';

/// A simple ghost finger drawn with shapes, animated along a path that depends
/// on [stepId]. Under reduce motion it is drawn at its end position statically.
class GhostFinger extends StatefulWidget {
  const GhostFinger({
    super.key,
    required this.stepId,
    this.color,
    this.size = 120,
  });

  final GestureSchoolStepId stepId;
  final Color? color;
  final double size;

  @override
  State<GhostFinger> createState() => _GhostFingerState();
}

class _GhostFingerState extends State<GhostFinger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _controller.stop();
      _controller.value = 1.0;
    } else {
      if (!_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: GhostFingerPainter(
            stepId: widget.stepId,
            color: color,
            progress: _controller,
            reduceMotion: reduce,
          ),
        ),
      ),
    );
  }
}

class GhostFingerPainter extends CustomPainter {
  GhostFingerPainter({
    required this.stepId,
    required this.color,
    required this.progress,
    required this.reduceMotion,
  }) : super(repaint: progress);

  final GestureSchoolStepId stepId;
  final Color color;
  final Animation<double> progress;
  final bool reduceMotion;

  int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount++;
    final t = reduceMotion ? 1.0 : progress.value;
    final w = size.width;
    final h = size.height;
    final dotPaint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Offset finger(double x, double y) => Offset(x, y);

    switch (stepId) {
      case GestureSchoolStepId.scroll:
        {
          final y = h * (0.2 + 0.6 * t);
          canvas.drawCircle(finger(w * 0.5, y), 10, dotPaint);
          canvas.drawLine(
            finger(w * 0.5, y),
            finger(w * 0.5, y + 18),
            strokePaint,
          );
        }
        break;
      case GestureSchoolStepId.capture:
        {
          canvas.drawCircle(finger(w * 0.5, h * 0.5), 10, dotPaint);
          canvas.drawLine(
            finger(w * 0.5, h * 0.5),
            finger(w * 0.5, h * 0.5 + 18),
            strokePaint,
          );
        }
        break;
      case GestureSchoolStepId.complete:
        {
          final x = w * (0.3 + 0.4 * t);
          canvas.drawCircle(finger(x, h * 0.5), 10, dotPaint);
          canvas.drawLine(
            finger(x, h * 0.5),
            finger(x, h * 0.5 + 18),
            strokePaint,
          );
        }
        break;
      case GestureSchoolStepId.push:
        {
          final x = w * (0.7 - 0.4 * t);
          canvas.drawCircle(finger(x, h * 0.5), 10, dotPaint);
          canvas.drawLine(
            finger(x, h * 0.5),
            finger(x, h * 0.5 + 18),
            strokePaint,
          );
        }
        break;
      case GestureSchoolStepId.dragSchedule:
        {
          final x = w * (0.2 + 0.6 * t);
          final y = h * (0.3 + 0.4 * t);
          canvas.drawCircle(finger(x, y), 10, dotPaint);
          canvas.drawLine(finger(x, y), finger(x, y + 18), strokePaint);
          // target
          canvas.drawCircle(finger(w * 0.8, h * 0.7), 12, strokePaint);
        }
        break;
      case GestureSchoolStepId.pinch:
        {
          final d = 0.1 + 0.3 * t;
          canvas.drawCircle(finger(w * (0.5 - d), h * 0.5), 8, dotPaint);
          canvas.drawCircle(finger(w * (0.5 + d), h * 0.5), 8, dotPaint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant GhostFingerPainter oldDelegate) {
    return oldDelegate.stepId != stepId ||
        oldDelegate.color != color ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}
