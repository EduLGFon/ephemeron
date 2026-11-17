import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// Returns black or white depending on the luminance of [color], so the check
/// mark stays visible on any hue.
Color contrastColorFor(Color color) {
  // Aligned with painter_helpers.dart (_contrast uses 0.55) for consistency.
  final luminance = color.computeLuminance();
  return luminance > 0.55 ? Colors.black : Colors.white;
}

/// Small habit glyph. Done state is conveyed by filled vs outlined shape plus
/// semantics, never by colour alone. The hit target is at least 48 dp even
/// though the visual is small.
class HabitGlyph extends StatelessWidget {
  const HabitGlyph({
    super.key,
    required this.done,
    required this.colorArgb,
    required this.semanticsLabel,
    this.size = 14,
    this.onTap,
    this.onLongPress,
  });

  final bool done;
  final int colorArgb;
  final String semanticsLabel;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorArgb);
    final checkColor = contrastColorFor(color);
    final visual = SizedBox(
      width: size + StreamSpacing.x1 * 2,
      height: size + StreamSpacing.x1 * 2,
      child: CustomPaint(
        painter: _HabitGlyphPainter(
          done: done,
          color: color,
          checkColor: checkColor,
        ),
      ),
    );
    return Semantics(
      label: semanticsLabel,
      button: true,
      toggled: done,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(child: visual),
        ),
      ),
    );
  }
}

class _HabitGlyphPainter extends CustomPainter {
  _HabitGlyphPainter({
    required this.done,
    required this.color,
    required this.checkColor,
  });

  final bool done;
  final Color color;
  final Color checkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Rect.fromLTWH(0, 0, 3, size.height);
    canvas.drawRect(bar, Paint()..color = color);

    final center = Offset(size.width / 2 + 1.5, size.height / 2);
    final radius = (size.shortestSide / 2) - 2;
    final paint = Paint()
      ..color = color
      ..style = done ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, paint);
    if (done) {
      final check = Paint()
        ..color = checkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(center.dx - radius * 0.45, center.dy)
        ..lineTo(center.dx - radius * 0.1, center.dy + radius * 0.35)
        ..lineTo(center.dx + radius * 0.5, center.dy - radius * 0.35);
      canvas.drawPath(path, check);
    }
  }

  @override
  bool shouldRepaint(covariant _HabitGlyphPainter old) =>
      old.done != done || old.color != color || old.checkColor != checkColor;
}
