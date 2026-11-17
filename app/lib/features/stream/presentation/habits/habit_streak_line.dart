import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// Continuous streak line for Week/Month levels.
///
/// Connects consecutive done days; breaks across gaps. Optional dots (Week
/// level) are drawn per day.
class HabitStreakLine extends StatelessWidget {
  const HabitStreakLine({
    super.key,
    required this.doneByDay,
    required this.cellWidth,
    required this.colorArgb,
    this.dayKeys,
    this.days,
    this.dayCount,
    this.startDate,
    this.weekLevel = true,
    this.showDots,
    this.semanticsLabel,
    this.streakCurrent = 0,
    this.duration = StreamMotion.fast,
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
  final String? semanticsLabel;
  final int streakCurrent;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final keys = _resolveKeys();
    final done = <bool>[for (final k in keys) doneByDay[k] ?? false];
    final dots = showDots ?? weekLevel;
    final disable = MediaQuery.disableAnimationsOf(context);
    final effectiveDuration = disable ? Duration.zero : duration;

    Widget content = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: effectiveDuration,
      builder: (context, value, child) {
        return CustomPaint(
          size: Size(cellWidth * keys.length, 24),
          painter: _StreakPainter(
            done: done,
            cellWidth: cellWidth,
            color: Color(colorArgb),
            showDots: dots,
            progress: value,
          ),
        );
      },
    );

    if (semanticsLabel != null) {
      content = Semantics(
        label: '$semanticsLabel, streak $streakCurrent',
        child: content,
      );
    }

    return content;
  }

  List<String> _resolveKeys() {
    if (dayKeys != null) return dayKeys!;
    if (days != null) return days!;
    final count = dayCount ?? 0;
    if (count <= 0) return const <String>[];
    if (startDate != null) {
      final out = <String>[];
      for (var i = 0; i < count; i++) {
        final d = DateTime(
          startDate!.year,
          startDate!.month,
          startDate!.day + i,
        );
        out.add(
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        );
      }
      return out;
    }
    // Fallback keys (rarely match date maps); prefer dayKeys/days/startDate.
    return List<String>.generate(count, (i) => '$i');
  }
}

class _StreakPainter extends CustomPainter {
  _StreakPainter({
    required this.done,
    required this.cellWidth,
    required this.color,
    required this.showDots,
    required this.progress,
  });

  final List<bool> done;
  final double cellWidth;
  final Color color;
  final bool showDots;
  final double progress;

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

    final visibleCount = (done.length * progress).ceil().clamp(0, done.length);

    // Draw line segments between consecutive done days.
    for (var i = 0; i + 1 < visibleCount; i++) {
      if (done[i] && done[i + 1]) {
        final x0 = i * cellWidth + cellWidth / 2;
        final x1 = (i + 1) * cellWidth + cellWidth / 2;
        final y = size.height / 2;
        canvas.drawLine(Offset(x0, y), Offset(x1, y), linePaint);
      }
    }

    if (showDots) {
      for (var i = 0; i < visibleCount; i++) {
        final center = Offset(i * cellWidth + cellWidth / 2, size.height / 2);
        if (done[i]) {
          canvas.drawCircle(center, 3, dotPaint);
        } else {
          canvas.drawCircle(center, 3, emptyDotPaint);
        }
      }
    } else {
      for (var i = 0; i < visibleCount; i++) {
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
      old.showDots != showDots ||
      old.progress != progress;
}
