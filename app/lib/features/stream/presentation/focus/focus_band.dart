// Focus band painter for the stream. Active mode grows from the session start
// to "now"; completed mode is a thin accent segment. Repaints only through the
// supplied listenable; no blur or opacity on animated subtrees.
import 'package:material_ui/material_ui.dart';

enum FocusBandMode { active, completed }

class FocusBandPainter extends CustomPainter {
  FocusBandPainter({
    required this.mode,
    this.progress = 0.0,
    this.segmentStart = 0.0,
    this.segmentEnd = 0.0,
    required this.color,
    this.thickness = 3.0,
    Listenable? repaintListenable,
  }) : super(repaint: repaintListenable);

  final FocusBandMode mode;
  final double progress;
  final double segmentStart;
  final double segmentEnd;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    if (size.height <= 0 || size.width <= 0) return;
    if (mode == FocusBandMode.active) {
      final end = (size.height * progress).clamp(0.0, size.height);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, thickness.clamp(0.0, size.width), end),
        paint,
      );
    } else {
      final top = (size.height * segmentStart).clamp(0.0, size.height);
      final bottom = (size.height * segmentEnd).clamp(0.0, size.height);
      final rawHeight = (bottom - top).abs();
      final drawnHeight = rawHeight < thickness
          ? (thickness <= size.height ? thickness : size.height)
          : rawHeight.clamp(0.0, size.height);
      if (drawnHeight <= 0) return;
      final clampedTop = top.clamp(0.0, size.height - drawnHeight);
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          clampedTop,
          thickness.clamp(0.0, size.width),
          drawnHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FocusBandPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.progress != progress ||
        oldDelegate.segmentStart != segmentStart ||
        oldDelegate.segmentEnd != segmentEnd ||
        oldDelegate.color != color ||
        oldDelegate.thickness != thickness;
  }
}

class FocusBand extends StatelessWidget {
  const FocusBand({
    super.key,
    required this.mode,
    this.progress = 0.0,
    this.segmentStart = 0.0,
    this.segmentEnd = 0.0,
    required this.color,
    this.thickness = 3.0,
    this.repaintListenable,
    this.semanticsLabel,
    this.elapsedText,
    this.label,
  });

  final FocusBandMode mode;
  final double progress;
  final double segmentStart;
  final double segmentEnd;
  final Color color;
  final double thickness;
  final Listenable? repaintListenable;
  final String? semanticsLabel;
  final String? elapsedText;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? label,
      value: elapsedText,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: FocusBandPainter(
            mode: mode,
            progress: progress,
            segmentStart: segmentStart,
            segmentEnd: segmentEnd,
            color: color,
            thickness: thickness,
            repaintListenable: repaintListenable,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
