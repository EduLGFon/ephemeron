import 'package:material_ui/material_ui.dart';

/// Colours for the day canvas, derived from the active theme so the canvas
/// stays readable in light, dark and true-black themes.
class DayCanvasStyle {
  const DayCanvasStyle({
    required this.hairline,
    required this.title,
    required this.subtitle,
    required this.blockFillAlpha,
  });

  final Color hairline;
  final Color title;
  final Color subtitle;
  final double blockFillAlpha;

  static DayCanvasStyle fromColorScheme(ColorScheme scheme) {
    return DayCanvasStyle(
      hairline: scheme.outlineVariant,
      title: scheme.onSurface,
      subtitle: scheme.onSurfaceVariant,
      blockFillAlpha: 0.18,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DayCanvasStyle &&
      other.hairline == hairline &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.blockFillAlpha == blockFillAlpha;

  @override
  int get hashCode => Object.hash(hairline, title, subtitle, blockFillAlpha);
}
