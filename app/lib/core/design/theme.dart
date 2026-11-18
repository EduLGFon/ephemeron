// Ephemeron Material 3 theme. The seeded scheme is flattened onto hand-tuned
// warm neutral surfaces: no elevation, 1px hairlines and tonal fills. AMOLED is
// a true-black scheme. Component themes resolve hover, focus and pressed states
// so custom components can match the built-ins.
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';
import 'typography.dart';

const PageTransitionsTheme _transitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  },
);

abstract final class EphemeronTheme {
  /// Ember, the brand seed used when the user has not picked an accent.
  static const Color brandAccent = Color(0xFFC2410C);

  /// Resolves a stored mode to the brightness to paint. Unknown values follow
  /// the platform, matching the `system` fallback used by settings.
  static Brightness resolveBrightness(
    String mode,
    Brightness platformBrightness,
  ) {
    return switch (mode.trim().toLowerCase()) {
      'light' => Brightness.light,
      'dark' || 'amoled' => Brightness.dark,
      _ => platformBrightness,
    };
  }

  static ThemeData build({
    required String mode,
    required Brightness platformBrightness,
    Color? accent,
    Color? background,
    bool dynamicColor = false,
    Color? dynamicAccent,
    bool compact = false,
  }) {
    final normalizedMode = mode.trim().toLowerCase();
    final brightness = resolveBrightness(normalizedMode, platformBrightness);
    final isAmoled = normalizedMode == 'amoled';
    final surface = isAmoled
        ? Colors.black
        : background ??
              (brightness == Brightness.dark
                  ? DsSurfaces.dark
                  : DsSurfaces.light);
    final seed = dynamicColor && dynamicAccent != null
        ? dynamicAccent
        : accent ?? brandAccent;
    final c = DsColorScheme.build(
      seed: seed,
      brightness: brightness,
      surface: surface,
      amoled: isAmoled,
    );
    final t = DsType.textTheme(brightness)
        .apply(bodyColor: c.onSurface, displayColor: c.onSurface);
    final line = BorderSide(color: c.outlineVariant);
    final md = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DsRadius.md),
    );
    final lg = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DsRadius.lg),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: c,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      fontFamily: DsType.inter,
      textTheme: t,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      pageTransitionsTheme: _transitions,
      appBarTheme: AppBarThemeData(
        backgroundColor: surface,
        foregroundColor: c.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: c.onSurface),
        actionsIconTheme: IconThemeData(color: c.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DsRadius.lg),
          side: line,
        ),
      ),
      dividerTheme: DividerThemeData(color: c.outlineVariant, space: 1),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DsSpace.x16,
          vertical: DsSpace.x12,
        ),
        hintStyle: t.bodyLarge?.copyWith(color: c.onSurfaceVariant),
        labelStyle: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        errorStyle: t.bodySmall?.copyWith(color: c.error),
        border: _inputBorder(c.outline),
        enabledBorder: _inputBorder(c.outline),
        focusedBorder: _inputBorder(c.primary, 1.5),
        focusedErrorBorder: _inputBorder(c.error, 1.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceContainerHigh,
        selectedColor: c.secondaryContainer,
        side: line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(DsRadius.pill)),
        ),
        labelStyle: t.labelMedium?.copyWith(color: c.onSurfaceVariant),
        elevation: 0,
        pressElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverseSurface,
        contentTextStyle: t.bodyMedium?.copyWith(color: c.onInverseSurface),
        actionTextColor: c.inversePrimary,
        elevation: 0,
        insetPadding: const EdgeInsets.all(DsSpace.x16),
        shape: md,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceContainerLow,
        modalBackgroundColor: c.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DsRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DsRadius.xl),
          side: line,
        ),
        titleTextStyle: t.headlineSmall?.copyWith(color: c.onSurface),
        contentTextStyle: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _button(c.onPrimary, c.onPrimary, background: c.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _button(
          c.primary,
          c.primary,
          side: BorderSide(color: c.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _button(c.primary, c.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        shape: lg,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.secondaryContainer,
        indicatorShape: lg,
        iconTheme: _navIcons(c),
        labelTextStyle: _navLabels(c, t),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: c.secondaryContainer,
        indicatorShape: lg,
        selectedIconTheme: IconThemeData(
          size: DsIcon.md,
          color: c.onSecondaryContainer,
        ),
        unselectedIconTheme: IconThemeData(
          size: DsIcon.md,
          color: c.onSurfaceVariant,
        ),
        selectedLabelTextStyle: t.labelMedium?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: t.labelMedium?.copyWith(
          color: c.onSurfaceVariant,
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: c.secondaryContainer,
        indicatorShape: lg,
        tileHeight: 48,
        iconTheme: _navIcons(c),
        labelTextStyle: _navLabels(c, t),
      ),
    );
  }
}

ButtonStyle _button(
  Color foreground,
  Color overlay, {
  Color? background,
  BorderSide? side,
}) => ButtonStyle(
  backgroundColor: background == null
      ? null
      : WidgetStatePropertyAll<Color?>(background),
  foregroundColor: WidgetStatePropertyAll<Color?>(foreground),
  overlayColor: _overlay(overlay),
  side: side == null ? null : WidgetStatePropertyAll<BorderSide?>(side),
  shape: const WidgetStatePropertyAll<OutlinedBorder?>(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(DsRadius.md)),
    ),
  ),
  minimumSize: const WidgetStatePropertyAll<Size?>(Size(0, 48)),
  animationDuration: DsMotion.fast,
);

WidgetStateProperty<IconThemeData?> _navIcons(ColorScheme scheme) {
  return WidgetStateProperty.resolveWith<IconThemeData?>(
    (states) => IconThemeData(
      size: DsIcon.md,
      color: states.contains(WidgetState.selected)
          ? scheme.onSecondaryContainer
          : scheme.onSurfaceVariant,
    ),
  );
}

WidgetStateProperty<TextStyle?> _navLabels(ColorScheme scheme, TextTheme text) {
  return WidgetStateProperty.resolveWith<TextStyle?>(
    (states) => text.labelLarge?.copyWith(
      color: states.contains(WidgetState.selected)
          ? scheme.onSecondaryContainer
          : scheme.onSurfaceVariant,
      fontWeight: states.contains(WidgetState.selected)
          ? FontWeight.w600
          : FontWeight.w500,
    ),
  );
}

WidgetStateProperty<Color?> _overlay(Color color) {
  return WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.pressed)) {
      return color.withValues(alpha: 0.16);
    }
    if (states.contains(WidgetState.focused)) {
      return color.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return color.withValues(alpha: 0.08);
    }
    return null;
  });
}

OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(DsRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
