import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('new preference keys have safe defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = SettingsRepository(await SharedPreferences.getInstance());

    expect(repo.streamEnabled, isFalse);
    expect(repo.dynamicColor, isFalse);
    expect(repo.uiDensity, 'comfortable');
    expect(repo.time24h, isTrue);
    expect(repo.navOrderV2, SettingsRepository.defaultNavOrderV2);
    expect(repo.navOrderV2, <int>[0, 1, 2, 3, 4]);
    expect(repo.navVersion, 0);
    expect(repo.brightness, 'light');
  });

  test('new preference keys persist round trips', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = SettingsRepository(await SharedPreferences.getInstance());

    await repo.setStreamEnabled(true);
    await repo.setDynamicColor(true);
    await repo.setUiDensity('compact');
    await repo.setTime24h(false);
    await repo.setNavOrderV2(<int>[4, 3, 2, 1, 0]);
    await repo.setNavVersion(2);
    await repo.setBrightness('system');

    expect(repo.streamEnabled, isTrue);
    expect(repo.dynamicColor, isTrue);
    expect(repo.uiDensity, 'compact');
    expect(repo.time24h, isFalse);
    expect(repo.navOrderV2, <int>[4, 3, 2, 1, 0]);
    expect(repo.navVersion, 2);
    expect(repo.brightness, 'system');
  });

  test(
    'navOrderV2 drops unknown ids and duplicates, appends missing',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings.navOrderV2': <String>['4', '4', '9', '-1', 'foo', '2'],
      });
      final repo = SettingsRepository(await SharedPreferences.getInstance());

      expect(repo.navOrderV2, <int>[4, 2, 0, 1, 3]);
    },
  );

  test('invalid density and fully invalid order fall back safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.uiDensity': 'giant',
      'settings.navOrderV2': <String>['x', '99'],
    });
    final repo = SettingsRepository(await SharedPreferences.getInstance());

    expect(repo.uiDensity, 'comfortable');
    expect(repo.navOrderV2, SettingsRepository.defaultNavOrderV2);
    await repo.setUiDensity('giant');
    expect(repo.uiDensity, 'comfortable');
  });
}
