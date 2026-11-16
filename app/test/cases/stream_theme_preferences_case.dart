import 'package:ephemeron/features/stream/application/stream_theme_preferences.dart';
import 'package:ephemeron/features/stream/application/stream_theme_provider.dart';
import 'package:ephemeron/features/stream/design/stream_theme_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('default system when nothing stored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = StreamThemePreferences(() async => prefs);
    expect(await repo.read(), StreamThemeMode.system);
  });

  test('write then read round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = StreamThemePreferences(() async => prefs);
    await repo.write(StreamThemeMode.trueBlack);
    expect(await repo.read(), StreamThemeMode.trueBlack);
  });

  test('bad stored value falls back to system', () async {
    SharedPreferences.setMockInitialValues({
      StreamThemePreferences.storageKey: 'garbage',
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = StreamThemePreferences(() async => prefs);
    expect(await repo.read(), StreamThemeMode.system);
  });

  test('notifier changes state and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        streamThemePreferencesProvider.overrideWithValue(
          StreamThemePreferences(() async => prefs),
        ),
      ],
    );
    addTearDown(container.dispose);
    await pumpEventQueue();
    container.read(streamThemeProvider.notifier).setMode(StreamThemeMode.dark);
    await pumpEventQueue();
    expect(container.read(streamThemeProvider), StreamThemeMode.dark);
    final stored = prefs.getString(StreamThemePreferences.storageKey);
    expect(stored, 'dark');
  });

  test('dispose before load completes does not throw', () async {
    final completer = Completer<SharedPreferences>();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        streamThemePreferencesProvider.overrideWithValue(
          StreamThemePreferences(() => completer.future),
        ),
      ],
    );
    container.dispose();
    completer.complete(prefs);
    await pumpEventQueue();
  });
}
