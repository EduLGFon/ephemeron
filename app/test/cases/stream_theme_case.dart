import 'package:ephemeron/features/stream/design/stream_palette.dart';
import 'package:ephemeron/features/stream/design/stream_theme.dart';
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:ephemeron/features/stream/design/stream_tokens.dart';
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

  test('fontFamily is Inter and text sizes from tokens', () {
    final t = streamThemeData(StreamThemeMode.light, Brightness.light);
    expect(t.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(t.textTheme.bodyLarge?.fontSize, StreamTypeScale.md);
    expect(t.textTheme.bodyMedium?.fontSize, StreamTypeScale.sm);
  });

  test('ThemeData colorScheme pairings pass WCAG AA', () {
    for (final mode in [
      StreamThemeMode.light,
      StreamThemeMode.dark,
      StreamThemeMode.trueBlack,
    ]) {
      final brightness = mode == StreamThemeMode.light
          ? Brightness.light
          : Brightness.dark;
      final t = streamThemeData(mode, brightness);
      final cs = t.colorScheme;
      final textRatio = streamContrastRatio(cs.onSurface, cs.surface);
      expect(textRatio, greaterThanOrEqualTo(4.5));
      final errorRatio = streamContrastRatio(cs.error, cs.surface);
      expect(errorRatio, greaterThanOrEqualTo(4.5));
      final onErrorRatio = streamContrastRatio(cs.onError, cs.error);
      expect(onErrorRatio, greaterThanOrEqualTo(4.5));
    }
  });

  test('exactly 8 accents', () {
    expect(streamAccents.length, 8);
  });

  test('light accent hues on light surface pass 3:1', () {
    for (final a in streamAccents) {
      expect(
        streamContrastRatio(a.light, StreamSurfaces.light),
        greaterThanOrEqualTo(3.0),
      );
    }
  });

  test('dark accent hues on dark surface pass 3:1', () {
    for (final a in streamAccents) {
      expect(
        streamContrastRatio(a.dark, StreamSurfaces.dark),
        greaterThanOrEqualTo(3.0),
      );
    }
  });

  test('dark accent hues on trueBlack surface pass 3:1', () {
    for (final a in streamAccents) {
      expect(
        streamContrastRatio(a.dark, StreamSurfaces.trueBlack),
        greaterThanOrEqualTo(3.0),
      );
    }
  });

  test('error pairings pass WCAG AA', () {
    final modes = <(StreamThemeMode, Brightness, Color, Color, Color)>[
      (
        StreamThemeMode.light,
        Brightness.light,
        StreamSurfaces.light,
        StreamErrorColors.light,
        StreamOnErrorColors.light,
      ),
      (
        StreamThemeMode.dark,
        Brightness.dark,
        StreamSurfaces.dark,
        StreamErrorColors.dark,
        StreamOnErrorColors.dark,
      ),
      (
        StreamThemeMode.trueBlack,
        Brightness.dark,
        StreamSurfaces.trueBlack,
        StreamErrorColors.trueBlack,
        StreamOnErrorColors.trueBlack,
      ),
    ];
    for (final m in modes) {
      expect(streamContrastRatio(m.$4, m.$3), greaterThanOrEqualTo(4.5));
      expect(streamContrastRatio(m.$5, m.$4), greaterThanOrEqualTo(4.5));
    }
  });

  test('primary (accent) meets 3:1 on each surface', () {
    expect(
      streamContrastRatio(streamAccents.first.light, StreamSurfaces.light),
      greaterThanOrEqualTo(3.0),
    );
    expect(
      streamContrastRatio(streamAccents.first.dark, StreamSurfaces.dark),
      greaterThanOrEqualTo(3.0),
    );
    expect(
      streamContrastRatio(streamAccents.first.dark, StreamSurfaces.trueBlack),
      greaterThanOrEqualTo(3.0),
    );
  });

  test('hairlines differ from surfaces', () {
    expect(StreamHairlines.light, isNot(StreamSurfaces.light));
    expect(StreamHairlines.dark, isNot(StreamSurfaces.dark));
    expect(StreamHairlines.trueBlack, isNot(StreamSurfaces.trueBlack));
  });
}
