import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Neutral surfaces, text and hairlines for the Stream themes.
abstract final class StreamSurfaces {
  static const Color light = Color(0xFFFFFFFF);
  static const Color dark = Color(0xFF121212);
  static const Color trueBlack = Color(0xFF000000);
}

abstract final class StreamTextColors {
  static const Color light = Color(0xFF1A1A1A);
  static const Color dark = Color(0xFFEDEDED);
  static const Color trueBlack = Color(0xFFF2F2F2);
}

/// Hairlines are decorative only: not for interactive borders or focus rings.
/// Interactive borders/focus must use primary or another 3:1 colour.
abstract final class StreamHairlines {
  static const Color light = Color(0xFFD9D9D9);
  static const Color dark = Color(0xFF2E2E2E);
  static const Color trueBlack = Color(0xFF1F1F1F);
}

/// Error colours per mode. onError is chosen for 4.5:1 on the error colour.
abstract final class StreamErrorColors {
  static const Color light = Color(0xFFB00020);
  static const Color dark = Color(0xFFCF6679);
  static const Color trueBlack = Color(0xFFCF6679);
}

abstract final class StreamOnErrorColors {
  static const Color light = Color(0xFFFFFFFF);
  static const Color dark = Color(0xFF000000);
  static const Color trueBlack = Color(0xFF000000);
}

/// Accents are for non-text UI only (3:1 rule), never for text.
class StreamAccent {
  const StreamAccent({required this.light, required this.dark});

  final Color light;
  final Color dark;
}

const List<StreamAccent> streamAccents = <StreamAccent>[
  StreamAccent(light: Color(0xFF1E6FD9), dark: Color(0xFF7CB6FF)),
  StreamAccent(light: Color(0xFF00897B), dark: Color(0xFF4DB6AC)),
  StreamAccent(light: Color(0xFF43A047), dark: Color(0xFF81C784)),
  StreamAccent(light: Color(0xFFB8860B), dark: Color(0xFFFFD54F)),
  StreamAccent(light: Color(0xFFE65100), dark: Color(0xFFFFB74D)),
  StreamAccent(light: Color(0xFFC62828), dark: Color(0xFFEF9A9A)),
  StreamAccent(light: Color(0xFFC2185B), dark: Color(0xFFF48FB1)),
  StreamAccent(light: Color(0xFF6A1B9A), dark: Color(0xFFCE93D8)),
];

double streamRelativeLuminance(Color color) {
  double channel(int v) {
    final s = v / 255.0;
    if (s <= 0.03928) return s / 12.92;
    return math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  final argb = color.toARGB32();
  return 0.2126 * channel((argb >> 16) & 0xFF) +
      0.7152 * channel((argb >> 8) & 0xFF) +
      0.0722 * channel(argb & 0xFF);
}

double streamContrastRatio(Color a, Color b) {
  final la = streamRelativeLuminance(a);
  final lb = streamRelativeLuminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double relativeLuminance(Color color) => streamRelativeLuminance(color);
double contrastRatio(Color a, Color b) => streamContrastRatio(a, b);
