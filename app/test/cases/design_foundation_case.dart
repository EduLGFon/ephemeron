import 'dart:math' as math;

import 'package:ephemeron/core/design/layout.dart';
import 'package:ephemeron/core/design/theme.dart';
import 'package:ephemeron/core/design/tokens.dart';
import 'package:ephemeron/core/design/typography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('mode resolution', () {
    test('explicit modes ignore platform brightness', () {
      const cases = <(String, Brightness, Brightness)>[
        ('light', Brightness.dark, Brightness.light),
        ('dark', Brightness.light, Brightness.dark),
        ('amoled', Brightness.light, Brightness.dark),
      ];
      for (final (mode, platform, expected) in cases) {
        expect(EphemeronTheme.resolveBrightness(mode, platform), expected);
      }
    });

    test('system follows the platform and unknown modes fall back to it', () {
      const cases = <(String, Brightness, Brightness)>[
        ('system', Brightness.light, Brightness.light),
        ('system', Brightness.dark, Brightness.dark),
        ('sepia', Brightness.dark, Brightness.dark),
      ];
      for (final (mode, platform, expected) in cases) {
        expect(EphemeronTheme.resolveBrightness(mode, platform), expected);
      }
    });

    test(
      'build resolves system and keeps the ThemeData brightness in sync',
      () {
        final theme = EphemeronTheme.build(
          mode: 'system',
          platformBrightness: Brightness.dark,
        );
        expect(theme.brightness, Brightness.dark);
        expect(theme.colorScheme.brightness, Brightness.dark);
      },
    );
  });

  group('theme', () {
    test('default accent is Ember and custom accents seed the scheme', () {
      expect(EphemeronTheme.brandAccent, const Color(0xFFC2410C));

      ThemeData build({
        Color? accent,
        bool dynamicColor = false,
        Color? dynamic,
      }) {
        return EphemeronTheme.build(
          mode: 'light',
          platformBrightness: Brightness.light,
          accent: accent,
          dynamicColor: dynamicColor,
          dynamicAccent: dynamic,
        );
      }

      final ember = build();
      final blue = build(accent: Colors.blue);
      final green = build(accent: Colors.green);
      final dynamic = build(
        accent: Colors.blue,
        dynamicColor: true,
        dynamic: Colors.green,
      );

      expect(blue.colorScheme.primary, isNot(ember.colorScheme.primary));
      expect(dynamic.colorScheme.primary, green.colorScheme.primary);
    });

    test('amoled paints true black surfaces in dark mode', () {
      final theme = EphemeronTheme.build(
        mode: 'amoled',
        platformBrightness: Brightness.light,
      );

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, Colors.black);
      expect(theme.colorScheme.surface, Colors.black);
      expect(theme.colorScheme.surfaceContainerLowest, Colors.black);
      expect(theme.colorScheme.surfaceDim, Colors.black);
    });

    test('all modes keep text contrast at WCAG AA', () {
      for (final mode in <String>['light', 'dark', 'amoled']) {
        final scheme = EphemeronTheme.build(
          mode: mode,
          platformBrightness: Brightness.light,
        ).colorScheme;
        expect(
          _contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$mode onSurface',
        );
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$mode onSurfaceVariant',
        );
      }
    });

    test('component surfaces stay flat with no elevation', () {
      final theme = EphemeronTheme.build(
        mode: 'light',
        platformBrightness: Brightness.light,
      );

      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.bottomSheetTheme.modalElevation, 0);
      expect(theme.navigationBarTheme.elevation, 0);
      expect(theme.navigationRailTheme.elevation, 0);
    });
  });

  group('typography', () {
    test(
      'Inter carries body and UI, Fraunces carries display and headline',
      () {
        for (final brightness in Brightness.values) {
          final theme = DsType.textTheme(brightness);
          expect(theme.bodyMedium?.fontFamily, DsType.inter);
          expect(theme.bodyLarge?.fontFamily, DsType.inter);
          expect(theme.titleLarge?.fontFamily, DsType.inter);
          expect(theme.labelLarge?.fontFamily, DsType.inter);
          for (final style in <TextStyle?>[
            theme.displayLarge,
            theme.displayMedium,
            theme.displaySmall,
            theme.headlineLarge,
            theme.headlineMedium,
            theme.headlineSmall,
          ]) {
            expect(style?.fontFamily, DsType.fraunces);
            expect(style?.height, greaterThan(1));
          }
          expect(theme.bodyMedium?.height, greaterThan(1.3));
        }
      },
    );

    test('numeric applies tabular figures once and keeps other features', () {
      const base = TextStyle(
        fontFamily: DsType.inter,
        fontFeatures: <FontFeature>[FontFeature.enable('ss01')],
      );
      final numeric = DsType.numeric(base);

      expect(
        numeric.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(numeric.fontFeatures, contains(const FontFeature.enable('ss01')));

      final twice = DsType.numeric(numeric);
      expect(
        twice.fontFeatures
            ?.where((feature) => feature.feature == 'tnum')
            .length,
        1,
      );
    });
  });

  group('layout', () {
    test('widths map to compact, medium and expanded breakpoints', () {
      expect(layoutForWidth(0), AppLayout.compact);
      expect(layoutForWidth(599.9), AppLayout.compact);
      expect(layoutForWidth(600), AppLayout.medium);
      expect(layoutForWidth(839.9), AppLayout.medium);
      expect(layoutForWidth(840), AppLayout.expanded);
      expect(layoutForWidth(1440), AppLayout.expanded);
    });

    testWidgets('scope exposes the layout and is optional', (tester) async {
      AppLayout? inherited;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppLayoutScope(
            layout: AppLayout.expanded,
            child: Builder(
              builder: (context) {
                inherited = AppLayoutScope.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(inherited, AppLayout.expanded);

      AppLayout? missing = AppLayout.expanded;
      late BuildContext outside;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            outside = context;
            missing = AppLayoutScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(missing, isNull);
      expect(() => AppLayoutScope.of(outside), throwsA(isA<AssertionError>()));
    });
  });

  group('category palette', () {
    test('has ten distinct fills per brightness', () {
      expect(DsCategoryColors.count, 10);
      expect(
        _distinct(DsCategoryColors.all.map((category) => category.light)),
        10,
      );
      expect(
        _distinct(DsCategoryColors.all.map((category) => category.dark)),
        10,
      );
      expect(DsCategoryColors.forIndex(10), same(DsCategoryColors.all.first));
      expect(DsCategoryColors.forIndex(-1), same(DsCategoryColors.all.last));
    });

    test('fill and foreground pairs pass WCAG AA in light and dark', () {
      final lightSurface = EphemeronTheme.build(
        mode: 'light',
        platformBrightness: Brightness.light,
      ).colorScheme.surface;
      final darkSurface = EphemeronTheme.build(
        mode: 'dark',
        platformBrightness: Brightness.dark,
      ).colorScheme.surface;

      for (final category in DsCategoryColors.all) {
        final pairs = <(Color, Color)>[
          (category.light, category.onLight),
          (category.dark, category.onDark),
          (category.light, lightSurface),
          (category.dark, darkSurface),
        ];
        for (final (fill, foreground) in pairs) {
          expect(_contrast(fill, foreground), greaterThanOrEqualTo(4.5));
        }
        expect(category.fill(Brightness.light), category.light);
        expect(category.foreground(Brightness.dark), category.onDark);
      }
    });
  });

  test('compact density is opt-in', () {
    final comfortable = EphemeronTheme.build(
      mode: 'light',
      platformBrightness: Brightness.light,
    );
    final compact = EphemeronTheme.build(
      mode: 'light',
      platformBrightness: Brightness.light,
      compact: true,
    );

    expect(comfortable.visualDensity, VisualDensity.standard);
    expect(compact.visualDensity, VisualDensity.compact);
  });
}

int _distinct(Iterable<Color> colors) =>
    colors.map((color) => color.toARGB32()).toSet().length;

double _contrast(Color a, Color b) {
  final values = <double>[_luminance(a), _luminance(b)]..sort();
  return (values.last + 0.05) / (values.first + 0.05);
}

double _luminance(Color color) {
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
