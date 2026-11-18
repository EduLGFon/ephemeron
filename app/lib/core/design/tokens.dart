// Design tokens for the Ephemeron UI. Screens and components read spacing,
// radii, breakpoints, motion and icon sizes from here so the whole app stays
// on one scale instead of re-inventing values per screen.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Spacing scale. Layout code should stay on these steps.
abstract final class DsSpace {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x48 = 48;
}

/// Corner radii. [pill] caps to a full capsule at any practical size.
abstract final class DsRadius {
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r24 = 24;
  static const double pill = 999;
}

/// Shell breakpoints. Widths below [compact] use bottom navigation, widths
/// below [expanded] use a rail, and larger widths use the sidebar. [contentMax]
/// caps centered page content on expanded layouts.
abstract final class DsBreakpoints {
  static const double compact = 600;
  static const double expanded = 840;
  static const double contentMax = 1100;
}

/// Motion durations and curves. Features can collapse [Duration]s to zero when
/// the platform asks for reduced motion; the curves stay usable either way.
abstract final class DsMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 240);
  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1);
}

/// Icon sizes for dense, regular and feature iconography.
abstract final class DsIcon {
  static const double sm = 18;
  static const double md = 22;
  static const double lg = 28;
}

/// Warm neutral surfaces and lines for the flat theme. Foregrounds pass WCAG
/// AA on their surface; AMOLED replaces all surfaces with true black.
abstract final class DsSurfaces {
  static const Color light = Color(0xFFFAF9F7);
  static const Color dark = Color(0xFF111110);
  static const Color onLight = Color(0xFF1B1917);
  static const Color onDark = Color(0xFFF3F0EC);
  static const Color variantOnLight = Color(0xFF5C554E);
  static const Color variantOnDark = Color(0xFFB9B2A9);
  static const Color outlineLight = Color(0xFF7A7269);
  static const Color outlineDark = Color(0xFF8A8379);
  static const Color hairlineLight = Color(0xFFE2DED8);
  static const Color hairlineDark = Color(0xFF2B2926);
  static const Color hairlineAmoled = Color(0xFF242220);
}

/// One category identity with a fill and foreground pair for each brightness.
/// Category colours are decorative identity, never the only status signal.
class DsCategoryColor {
  const DsCategoryColor({
    required this.light,
    required this.dark,
    required this.onLight,
    required this.onDark,
  });

  /// Fill used on light surfaces.
  final Color light;

  /// Fill used on dark and AMOLED surfaces.
  final Color dark;

  /// Foreground painted on [light].
  final Color onLight;

  /// Foreground painted on [dark].
  final Color onDark;

  Color fill(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  Color foreground(Brightness brightness) =>
      brightness == Brightness.dark ? onDark : onLight;
}

/// Builds the seeded Material 3 scheme, then replaces its surfaces with the
/// flat warm ramp. AMOLED collapses the ramp to true black.
abstract final class DsColorScheme {
  static ColorScheme build({
    required Color seed,
    required Brightness brightness,
    required Color surface,
    required bool amoled,
  }) {
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final dark =
        ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
    // Prefer the warm foreground, but fall back to pure black or white when a
    // user-supplied mid-luminance background would fail AA.
    final on = _readable(
      surface,
      dark ? DsSurfaces.onDark : DsSurfaces.onLight,
    );
    final variant = _readable(
      surface,
      dark ? DsSurfaces.variantOnDark : DsSurfaces.variantOnLight,
      fallback: on,
    );
    final line = amoled
        ? DsSurfaces.hairlineAmoled
        : dark
        ? DsSurfaces.hairlineDark
        : DsSurfaces.hairlineLight;
    final ramp = amoled
        ? const <Color>[
            Colors.black,
            Color(0xFF0C0B0A),
            Color(0xFF131211),
            Color(0xFF1B1A18),
            DsSurfaces.hairlineAmoled,
          ]
        : <Color>[
            _mix(surface, on, dark ? 0.02 : 0),
            _mix(surface, on, dark ? 0.04 : 0.03),
            _mix(surface, on, dark ? 0.06 : 0.05),
            _mix(surface, on, dark ? 0.09 : 0.08),
            _mix(surface, on, dark ? 0.12 : 0.11),
          ];

    return base.copyWith(
      surface: surface,
      surfaceDim: dark
          ? (amoled ? Colors.black : _mix(surface, Colors.black, 0.2))
          : _mix(surface, on, 0.06),
      surfaceBright: dark ? _mix(surface, on, 0.14) : surface,
      surfaceContainerLowest: ramp[0],
      surfaceContainerLow: ramp[1],
      surfaceContainer: ramp[2],
      surfaceContainerHigh: ramp[3],
      surfaceContainerHighest: ramp[4],
      onSurface: on,
      onSurfaceVariant: variant,
      outline: dark ? DsSurfaces.outlineDark : DsSurfaces.outlineLight,
      outlineVariant: line,
      surfaceTint: Colors.transparent,
      inverseSurface: on,
      onInverseSurface: surface,
    );
  }

  /// Returns [preferred] when it reaches WCAG AA on [surface], else [fallback]
  /// when that passes, else whichever of black and white has more contrast.
  /// The black/white fallback always clears 4.5:1, including mid-luminance
  /// custom backgrounds where neither warm foreground can.
  static Color _readable(Color surface, Color preferred, {Color? fallback}) {
    if (_contrast(preferred, surface) >= 4.5) return preferred;
    if (fallback != null && _contrast(fallback, surface) >= 4.5) {
      return fallback;
    }
    return _contrast(Colors.white, surface) >= _contrast(Colors.black, surface)
        ? Colors.white
        : Colors.black;
  }

  static double _contrast(Color a, Color b) {
    final values = <double>[_luminance(a), _luminance(b)]..sort();
    return (values.last + 0.05) / (values.first + 0.05);
  }

  static double _luminance(Color color) {
    double channel(int value) {
      final c = value / 255.0;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final argb = color.toARGB32();
    return 0.2126 * channel((argb >> 16) & 0xFF) +
        0.7152 * channel((argb >> 8) & 0xFF) +
        0.0722 * channel(argb & 0xFF);
  }

  static Color _mix(Color base, Color overlay, double opacity) =>
      Color.alphaBlend(overlay.withValues(alpha: opacity), base);
}

/// Ten precomputed category colours. Every fill/foreground pair passes WCAG AA
/// (4.5:1) for text and small glyphs in its brightness.
abstract final class DsCategoryColors {
  static const List<DsCategoryColor> all = <DsCategoryColor>[
    DsCategoryColor(
      light: Color(0xFF1565C0), // Blue
      dark: Color(0xFF90CAF9),
      onLight: Color(0xFFFFFFFF),
      onDark: Color(0xFF000000),
    ),
    DsCategoryColor(
      light: Color(0xFF00695C), // Teal
      dark: Color(0xFF80CBC4),
      onLight: Color(0xFFFFFFFF),
      onDark: Color(0xFF000000),
    ),
    DsCategoryColor(
      light: Color(0xFF2E7D32), // Green
      dark: Color(0xFFA5D6A7),
      onLight: Color(0xFFFFFFFF),
      onDark: Color(0xFF000000),
    ),
    DsCategoryColor(
      light: Color(0xFF8A5A00), // Amber
      dark: Color(0xFFFFE082),
      onLight: Color(0xFFFFFFFF),
      onDark: Color(0xFF000000),
    ),
    DsCategoryColor(
      light: Color(0xFFBF360C), // Orange
      dark: Color(0xFFFFCC80),
      onLight: Color(0xFFFFFFFF),
      onDark: Color(0xFF000000),
    ),
    DsCategoryColor(
      light: Color(0xFFB71C1C), // Red
      dark: Color(0xFFEF9A9A),
      onLight: Color(0xFFFFFFFF),
      onDark: Color(0xFF000000),
    ),
    DsCategoryColor(
      light: Color(0xFFAD1457), // Pink
      dark: Color(0xFFF48FB1),
      onLight: Color(0xFFFFFFFF),
      onDark: Color(0xFF000000),
    ),
    DsCategoryColor(
      light: Color(0xFF6A1B9A), // Purple
      dark: Color(0xFFCE93D8),
      onLight: Color(0xFFFFFFFF),
      onDark: Color(0xFF000000),
    ),
    DsCategoryColor(
      light: Color(0xFF283593), // Indigo
      dark: Color(0xFF9FA8DA),
      onLight: Color(0xFFFFFFFF),
      onDark: Color(0xFF000000),
    ),
    DsCategoryColor(
      light: Color(0xFF455A64), // Slate
      dark: Color(0xFFB0BEC5),
      onLight: Color(0xFFFFFFFF),
      onDark: Color(0xFF000000),
    ),
  ];

  static int get count => all.length;

  /// Stable category identity for [index]; wraps for unknown indices so callers
  /// never key a colour on an unbounded id.
  static DsCategoryColor forIndex(int index) => all[index % all.length];
}
