import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// Continuous streak line for Week/Month levels.
///
/// Connects consecutive done days; breaks across gaps. Optional dots (Week
/// level) are drawn per day.
class HabitStreakLine extends StatefulWidget {
  const HabitStreakLine({
    super.key,
    required this.doneByDay,
    required this.cellWidth,
    this.dayKeys,
    this.days,
    this.dayCount,
    this.startDate,
    this.colorArgb = 0xFF4CAF50,
    this.weekLevel = true,
    this.showDots,
  });

  final Map<String, bool> doneByDay;
  final double cellWidth;
  final List<String>? dayKeys;
  final List<String>? days;
  final int? dayCount;
  final DateTime? startDate;
  final int colorArgb;
  final bool weekLevel;
  final bool? showDots;

  @override
  State<HabitStreakLine> createState() => _HabitStreakLineState();
}

class _HabitStreakLineState extends State<HabitStreakLine> {
  @override
  Widget build(BuildContext context) {
    final keys = _resolveKeys();
    final done = <bool>[for (final k in keys) widget.doneByDay[k] ?? false];
    final dots = widget.showDots ?? widget.weekLevel;
    final disable = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: 1,
      duration: disable ? Duration.zero : StreamMotion.fast,
      child: CustomPaint(
        size: Size(widget.cellWidth * keys.length, 24),
        painter: _StreakPainter(
          done: done,
          cellWidth: widget.cellWidth,
          color: Color(widget.colorArgb),
          showDots: dots,
        ),
      ),
    );
  }

  List<String> _resolveKeys() {
    if (widget.dayKeys != null) return widget.dayKeys!;
    if (widget.days != null) return widget.days!;
    final count = widget.dayCount ?? 0;
    if (count <= 0) return const <String>[];
    if (widget.startDate != null) {
      final out = <String>[];
      for (var i = 0; i < count; i++) {
        final d = widget.startDate!.add(Duration(days: i));
        out.add(
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        );
      }
      return out;
    }
    return List<String>.generate(count, (i) => '$i');
  }
}

class _StreakPainter extends CustomPainter {
  _StreakPainter({
    required this.done,
    required this.cellWidth,
    required this.color,
    required this.showDots,
  });

  final List<bool> done;
  final double cellWidth;
  final Color color;
  final bool showDots;

  @override
  void paint(Canvas canvas, Size size) {
    if (done.isEmpty) return;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = color;
    final emptyDotPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw line segments between consecutive done days.
    for (var i = 0; i + 1 < done.length; i++) {
      if (done[i] && done[i + 1]) {
        final x0 = i * cellWidth + cellWidth / 2;
        final x1 = (i + 1) * cellWidth + cellWidth / 2;
        final y = size.height / 2;
        canvas.drawLine(Offset(x0, y), Offset(x1, y), linePaint);
      }
    }

    if (showDots) {
      for (var i = 0; i < done.length; i++) {
        final center = Offset(i * cellWidth + cellWidth / 2, size.height / 2);
        if (done[i]) {
          canvas.drawCircle(center, 3, dotPaint);
        } else {
          canvas.drawCircle(center, 3, emptyDotPaint);
        }
      }
    } else {
      // Month level: dot only on done days.
      for (var i = 0; i < done.length; i++) {
        if (done[i]) {
          final center = Offset(i * cellWidth + cellWidth / 2, size.height / 2);
          canvas.drawCircle(center, 3, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StreakPainter old) =>
      old.done != done ||
      old.cellWidth != cellWidth ||
      old.color != color ||
      old.showDots != showDots;
}
