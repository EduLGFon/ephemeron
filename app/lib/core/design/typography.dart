// Typography scale for Ephemeron. Fraunces carries display and headline text;
// Inter carries controls, body copy and data. Numeric styles go through
// [DsType.numeric] so clocks, counters and tables use tabular figures.
import 'package:material_ui/material_ui.dart';

abstract final class DsType {
  static const String inter = 'Inter';
  static const String fraunces = 'Fraunces';

  /// The full Material text theme. Colours come from the base theme so the
  /// caller can apply the active scheme without rebuilding the scale.
  static TextTheme textTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness).textTheme
        .apply(fontFamily: inter);

    return base.copyWith(
      displayLarge: _display(base.displayLarge, 57, FontWeight.w400, 1.04, -1),
      displayMedium: _display(
        base.displayMedium,
        45,
        FontWeight.w400,
        1.07,
        -0.5,
      ),
      displaySmall: _display(
        base.displaySmall,
        36,
        FontWeight.w400,
        1.1,
        -0.25,
      ),
      headlineLarge: _display(base.headlineLarge, 32, FontWeight.w500, 1.15),
      headlineMedium: _display(base.headlineMedium, 28, FontWeight.w500, 1.18),
      headlineSmall: _display(base.headlineSmall, 24, FontWeight.w500, 1.2),
      titleLarge: _text(base.titleLarge, 22, FontWeight.w600, 1.25),
      titleMedium: _text(base.titleMedium, 16, FontWeight.w600, 1.3),
      titleSmall: _text(base.titleSmall, 14, FontWeight.w600, 1.3),
      bodyLarge: _text(base.bodyLarge, 16, FontWeight.w400, 1.5),
      bodyMedium: _text(base.bodyMedium, 14, FontWeight.w400, 1.45),
      bodySmall: _text(base.bodySmall, 12, FontWeight.w400, 1.4),
      labelLarge: _text(base.labelLarge, 14, FontWeight.w600, 1.2, 0.1),
      labelMedium: _text(base.labelMedium, 12, FontWeight.w600, 1.2, 0.2),
      labelSmall: _text(base.labelSmall, 11, FontWeight.w500, 1.2, 0.3),
    );
  }

  /// Adds tabular figures without dropping any existing font features. Safe to
  /// call more than once.
  static TextStyle numeric(TextStyle style) {
    final features = style.fontFeatures ?? const <FontFeature>[];
    if (features.any(
      (feature) => feature.feature == 'tnum' && feature.value > 0,
    )) {
      return style;
    }
    return style.copyWith(
      fontFeatures: <FontFeature>[
        ...features,
        const FontFeature.tabularFigures(),
      ],
    );
  }

  static TextStyle? _display(
    TextStyle? base,
    double size,
    FontWeight weight,
    double height, [
    double letterSpacing = 0,
  ]) {
    return _text(base, size, weight, height, letterSpacing, fraunces);
  }

  static TextStyle? _text(
    TextStyle? base,
    double size,
    FontWeight weight,
    double height, [
    double letterSpacing = 0,
    String family = inter,
  ]) {
    return base?.copyWith(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
