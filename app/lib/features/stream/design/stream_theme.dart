import 'package:material_ui/material_ui.dart';

import 'stream_palette.dart';
import 'stream_theme_mode.dart';
import 'stream_tokens.dart';

ThemeData streamThemeData(StreamThemeMode mode, Brightness platformBrightness) {
  final resolved = _resolveMode(mode, platformBrightness);
  final isDark =
      resolved == StreamThemeMode.dark || resolved == StreamThemeMode.trueBlack;
  final isTrueBlack = resolved == StreamThemeMode.trueBlack;

  final surface = _surfaceFor(isDark, isTrueBlack);
  final onSurface = _textFor(isDark, isTrueBlack);
  final hairline = _hairlineFor(isDark, isTrueBlack);
  final error = _errorFor(isDark, isTrueBlack);
  final onError = _onErrorFor(isDark, isTrueBlack);
  final accent = isDark ? streamAccents.first.dark : streamAccents.first.light;

  final brightness = isDark ? Brightness.dark : Brightness.light;
  final scheme = _colorScheme(
    brightness: brightness,
    accent: accent,
    surface: surface,
    onSurface: onSurface,
    hairline: hairline,
    error: error,
    onError: onError,
  );
  final textTheme = _streamTextTheme(brightness, onSurface);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    canvasColor: surface,
    fontFamily: streamFontFamily,
    textTheme: textTheme,
    dividerColor: hairline,
  );
}

StreamThemeMode _resolveMode(
  StreamThemeMode mode,
  Brightness platformBrightness,
) {
  if (mode != StreamThemeMode.system) return mode;
  return platformBrightness == Brightness.dark
      ? StreamThemeMode.dark
      : StreamThemeMode.light;
}

Color _surfaceFor(bool isDark, bool isTrueBlack) {
  if (isTrueBlack) return StreamSurfaces.trueBlack;
  return isDark ? StreamSurfaces.dark : StreamSurfaces.light;
}

Color _textFor(bool isDark, bool isTrueBlack) {
  if (isTrueBlack) return StreamTextColors.trueBlack;
  return isDark ? StreamTextColors.dark : StreamTextColors.light;
}

Color _hairlineFor(bool isDark, bool isTrueBlack) {
  if (isTrueBlack) return StreamHairlines.trueBlack;
  return isDark ? StreamHairlines.dark : StreamHairlines.light;
}

Color _errorFor(bool isDark, bool isTrueBlack) {
  if (isTrueBlack) return StreamErrorColors.trueBlack;
  return isDark ? StreamErrorColors.dark : StreamErrorColors.light;
}

Color _onErrorFor(bool isDark, bool isTrueBlack) {
  if (isTrueBlack) return StreamOnErrorColors.trueBlack;
  return isDark ? StreamOnErrorColors.dark : StreamOnErrorColors.light;
}

ColorScheme _colorScheme({
  required Brightness brightness,
  required Color accent,
  required Color surface,
  required Color onSurface,
  required Color hairline,
  required Color error,
  required Color onError,
}) {
  return ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
    secondary: accent,
    onSecondary: brightness == Brightness.dark ? Colors.black : Colors.white,
    error: error,
    onError: onError,
    surface: surface,
    onSurface: onSurface,
    outline: hairline,
    outlineVariant: hairline,
  );
}

TextTheme _streamTextTheme(Brightness brightness, Color onSurface) {
  final base = ThemeData(brightness: brightness).textTheme;
  final inter = base.apply(fontFamily: streamFontFamily);
  return inter.copyWith(
    displayLarge: inter.displayLarge?.copyWith(
      fontSize: StreamTypeScale.display,
      fontWeight: FontWeight.w300,
      height: StreamLineHeight.tight,
      color: onSurface,
    ),
    headlineLarge: inter.headlineLarge?.copyWith(
      fontSize: StreamTypeScale.xxl,
      fontWeight: FontWeight.w600,
      height: StreamLineHeight.tight,
      color: onSurface,
    ),
    titleLarge: inter.titleLarge?.copyWith(
      fontSize: StreamTypeScale.xl,
      fontWeight: FontWeight.w600,
      height: StreamLineHeight.normal,
      color: onSurface,
    ),
    bodyLarge: inter.bodyLarge?.copyWith(
      fontSize: StreamTypeScale.md,
      fontWeight: FontWeight.w400,
      height: StreamLineHeight.normal,
      color: onSurface,
    ),
    bodyMedium: inter.bodyMedium?.copyWith(
      fontSize: StreamTypeScale.sm,
      fontWeight: FontWeight.w400,
      height: StreamLineHeight.normal,
      color: onSurface,
    ),
    bodySmall: inter.bodySmall?.copyWith(
      fontSize: StreamTypeScale.xs,
      fontWeight: FontWeight.w400,
      height: StreamLineHeight.normal,
      color: onSurface,
    ),
    labelLarge: inter.labelLarge?.copyWith(
      fontSize: StreamTypeScale.sm,
      fontWeight: FontWeight.w500,
      height: StreamLineHeight.normal,
      color: onSurface,
    ),
  );
}
