import 'package:material_ui/material_ui.dart';

// 10 primary color presets (user picks one or enters a custom hex).
const List<Color> primaryPresets = <Color>[
  Color(0xFF1E88E5), // Blue
  Color(0xFF00897B), // Teal
  Color(0xFF43A047), // Green
  Color(0xFFFDD835), // Amber
  Color(0xFFFB8C00), // Orange
  Color(0xFFE53935), // Red
  Color(0xFFD81B60), // Pink
  Color(0xFF8E24AA), // Purple
  Color(0xFF3949AB), // Indigo
  Color(0xFF546E7A), // Slate
];

// 6 background presets (user picks one or enters a custom hex).
const List<Color> backgroundPresets = <Color>[
  Color(0xFFFFFFFF), // White
  Color(0xFFFBF7F0), // Warm
  Color(0xFFF2F5FA), // Cool
  Color(0xFF121212), // Dark
  Color(0xFF0B0B0D), // Darker
  Color(0xFF000000), // AMOLED black
];

enum AppBrightness { light, dark, amoled }

/// Spacing scale shared by layout primitives. Keep all new layout code on
/// these steps so spacing stays coherent across features.
abstract final class AppSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii. `pill` rounds to a full capsule at any practical size.
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Motion durations. Features should resolve them through `AppMotion` so the
/// reduce-motion setting can collapse them to zero.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
}

Color parseHex(String hex) {
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  if (v == null) return primaryPresets.first;
  return Color(v);
}

/// Canonical `#RRGGBB` representation used by settings and preset matching.
String colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

/// Null when [hex] is not a valid #RRGGBB or #AARRGGBB value.
bool isValidHex(String hex) {
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length != 6 && h.length != 8) return false;
  return int.tryParse(h, radix: 16) != null;
}
