import 'package:material_ui/material_ui.dart';

import 'stream_palette.dart';
import 'stream_theme_mode.dart';
import 'stream_tokens.dart';

/// Build a Stream-scoped [ThemeData]. App-wide theme is untouched.
ThemeData streamThemeData(StreamThemeMode mode, Brightness platformBrightness) {
  final resolved = mode == StreamThemeMode.system
      ? (platformBrightness == Brightness.dark
            ? StreamThemeMode.dark
            : StreamThemeMode.light)
      : mode;

  final isDark =
      resolved == StreamThemeMode.dark || resolved == StreamThemeMode.trueBlack;
  final isTrueBlack = resolved == StreamThemeMode.trueBlack;

  final surface = isTrueBlack
      ? StreamSurfaces.trueBlack
      : (isDark ? StreamSurfaces.dark : StreamSurfaces.light);
  final onSurface = isTrueBlack
      ? StreamTextColors.trueBlack
      : (isDark ? StreamTextColors.dark : StreamTextColors.light);
  final hairline = isTrueBlack
      ? StreamHairlines.trueBlack
      : (isDark ? StreamHairlines.dark : StreamHairlines.light);

  final accent = isDark ? streamAccents.first.dark : streamAccents.first.light;

  final brightness = isDark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: isDark ? Colors.black : Colors.white,
    secondary: accent,
    onSecondary: isDark ? Colors.black : Colors.white,
    error: const Color(0xFFB00020),
    onError: Colors.white,
    surface: surface,
    onSurface: onSurface,
    outline: hairline,
    outlineVariant: hairline,
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
