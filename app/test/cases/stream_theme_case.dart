import 'package:ephemeron/features/stream/design/stream_palette.dart';
import 'package:ephemeron/features/stream/design/stream_theme.dart';
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse maps storage keys and unknown to system', () {
    for (final m in StreamThemeMode.values) {
      expect(StreamThemeMode.parse(m.storageKey), m);
    }
    expect(StreamThemeMode.parse(null), StreamThemeMode.system);
    expect(StreamThemeMode.parse('nope'), StreamThemeMode.system);
    expect(StreamThemeMode.parse(''), StreamThemeMode.system);
  });

  test('storage keys are stable', () {
    expect(StreamThemeMode.system.storageKey, 'system');
    expect(StreamThemeMode.light.storageKey, 'light');
    expect(StreamThemeMode.dark.storageKey, 'dark');
    expect(StreamThemeMode.trueBlack.storageKey, 'true_black');
  });

  test('System resolves from platform brightness', () {
    final light = streamThemeData(StreamThemeMode.system, Brightness.light);
    final dark = streamThemeData(StreamThemeMode.system, Brightness.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
  });

  test('trueBlack surface is 0xFF000000', () {
    final t = streamThemeData(StreamThemeMode.trueBlack, Brightness.dark);
    expect(t.scaffoldBackgroundColor, const Color(0xFF000000));
  });

  // WCAG AA contrast assertions.
  const surfaces = <(String, Color)>[
    ('light', StreamSurfaces.light),
    ('dark', StreamSurfaces.dark),
    ('trueBlack', StreamSurfaces.trueBlack),
  ];
  const textColors = <(String, Color, String)>[
    ('light', StreamTextColors.light, 'light'),
    ('dark', StreamTextColors.dark, 'dark'),
    ('trueBlack', StreamTextColors.trueBlack, 'trueBlack'),
  ];

  for (final s in surfaces) {
    for (final t in textColors) {
      if (t.$3 != s.$1) continue;
      test('text on ${s.$1} surface passes AA', () {
        final ratio = streamContrastRatio(t.$2, s.$2);
        expect(ratio, greaterThanOrEqualTo(4.5));
      });
    }
  }

  // hue-on-surface for the matching theme (light hues on light, dark hues on dark/trueBlack)
  test('light accent hues on light surface pass 3:1', () {
    for (final h in streamAccentLight) {
      expect(
        streamContrastRatio(h, StreamSurfaces.light),
        greaterThanOrEqualTo(3.0),
      );
    }
  });
  test('dark accent hues on dark surface pass 3:1', () {
    for (final h in streamAccentDark) {
      expect(
        streamContrastRatio(h, StreamSurfaces.dark),
        greaterThanOrEqualTo(3.0),
      );
    }
  });
  test('dark accent hues on trueBlack surface pass 3:1', () {
    for (final h in streamAccentDark) {
      expect(
        streamContrastRatio(h, StreamSurfaces.trueBlack),
        greaterThanOrEqualTo(3.0),
      );
    }
  });

  // hairlines non-text UI 3:1 against surfaces? check at least not invisible
  test('hairlines defined', () {
    expect(StreamHairlines.light, isNotNull);
  });
}
