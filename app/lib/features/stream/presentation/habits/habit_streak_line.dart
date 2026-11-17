import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// Pure key generator for a streak range. Exposed for testing.
List<String> habitStreakDayKeys({
  List<String>? dayKeys,
  int? dayCount,
  DateTime? startDate,
}) {
  if (dayKeys != null) return dayKeys;
  final count = dayCount ?? 0;
  if (count <= 0) return const <String>[];
  assert(startDate != null, 'startDate is required when dayCount > 0');
  final out = <String>[];
  for (var i = 0; i < count; i++) {
    final d = DateTime(startDate!.year, startDate.month, startDate.day + i);
    out.add(
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    );
  }
  return out;
}

/// Pure layout descriptor for the streak painter. Exposed for testing.
class HabitStreakLayout {
  const HabitStreakLayout({
    required this.segments,
    required this.dots,
    required this.filledDots,
  });

  final int segments;
  final int dots;
  final int filledDots;
}

HabitStreakLayout computeHabitStreakLayout({
  required List<bool> done,
  required bool showDots,
  required double progress,
}) {
  final visibleCount = (done.length * progress).ceil().clamp(0, done.length);
  var segments = 0;
  for (var i = 0; i + 1 < visibleCount; i++) {
    if (done[i] && done[i + 1]) segments++;
  }
  var dots = 0;
  var filledDots = 0;
  if (showDots) {
    dots = visibleCount;
    for (var i = 0; i < visibleCount; i++) {
      if (done[i]) filledDots++;
    }
  } else {
    for (var i = 0; i < visibleCount; i++) {
      if (done[i]) {
        dots++;
        filledDots++;
      }
    }
  }
  return HabitStreakLayout(
    segments: segments,
    dots: dots,
    filledDots: filledDots,
  );
}

/// Continuous streak line for Week/Month levels.
class HabitStreakLine extends StatelessWidget {
  const HabitStreakLine({
    super.key,
    required this.doneByDay,
    required this.cellWidth,
    required this.colorArgb,
    required this.currentDayKey,
    this.dayKeys,
    this.dayCount,
    this.startDate,
    this.weekLevel = true,
    this.showDots,
    this.semanticsLabel,
    this.streakCurrent = 0,
    this.streakLabel,
    this.duration = StreamMotion.fast,
  });

  final Map<String, bool> doneByDay;
  final double cellWidth;
  final int colorArgb;
  final String currentDayKey;
  final List<String>? dayKeys;
  final int? dayCount;
  final DateTime? startDate;
  final bool weekLevel;
  final bool? showDots;
  final String? semanticsLabel;
  final int streakCurrent;
  final String Function(int streak)? streakLabel;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final keys = habitStreakDayKeys(
      dayKeys: dayKeys,
      dayCount: dayCount,
      startDate: startDate,
    );
    final done = <bool>[for (final k in keys) doneByDay[k] ?? false];
    final dots = showDots ?? weekLevel;
    final disable = MediaQuery.disableAnimationsOf(context);
    final effectiveDuration = disable ? Duration.zero : duration;
    final label = semanticsLabel == null
        ? null
        : streakLabel == null
        ? semanticsLabel
        : '$semanticsLabel, ${streakLabel!(streakCurrent)}';

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: effectiveDuration,
      builder: (context, value, child) {
        return Semantics(
          label: label,
          child: CustomPaint(
            size: Size(cellWidth * keys.length, 24),
            painter: _StreakPainter(
              done: done,
              cellWidth: cellWidth,
              color: Color(colorArgb),
              showDots: dots,
              progress: value,
              layout: computeHabitStreakLayout(
                done: done,
                showDots: dots,
                progress: value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StreakPainter extends CustomPainter {
  _StreakPainter({
    required this.done,
    required this.cellWidth,
    required this.color,
    required this.showDots,
    required this.progress,
    required this.layout,
  });

  final List<bool> done;
  final double cellWidth;
  final Color color;
  final bool showDots;
  final double progress;
  final HabitStreakLayout layout;

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
