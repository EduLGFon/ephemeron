// Empty-state art drawn with simple vector shapes. No assets, no blur, no
// shadows. Tinted from the theme colour passed in. Cheap: a handful of paths.
import 'package:material_ui/material_ui.dart';

/// A painter that draws a calm horizon with a few marks and a soft accent dot.
class StreamEmptyArtPainter extends CustomPainter {
  const StreamEmptyArtPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final accent = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Horizon line.
    final horizonY = h * 0.62;
    canvas.drawLine(
      Offset(w * 0.12, horizonY),
      Offset(w * 0.88, horizonY),
      stroke,
    );

    // A few small marks rising from the horizon.
    for (var i = 0; i < 4; i++) {
      final x = w * (0.22 + i * 0.18);
      final top = horizonY - h * (0.08 + i * 0.06);
      canvas.drawLine(Offset(x, horizonY), Offset(x, top), stroke);
    }

    // Soft accent dot above the horizon.
    canvas.drawCircle(Offset(w * 0.5, h * 0.28), w * 0.06, accent);
  }

  @override
  bool shouldRepaint(covariant StreamEmptyArtPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Convenience widget that sizes and tints the art from the theme.
class StreamEmptyArt extends StatelessWidget {
  const StreamEmptyArt({super.key, this.size = 96, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size(size, size),
      painter: StreamEmptyArtPainter(color: resolved),
    );
  }
}
