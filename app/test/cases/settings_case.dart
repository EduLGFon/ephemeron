import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ephemeron/features/settings/data/settings_repository.dart';

void main() {
  test('settings repository keeps old keys and new shell defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs);

    // Existing keys are unchanged.
    expect(repo.brightness, 'light');
    expect(repo.navOrder, [0, 1, 6, 3, 5, 4, 2]);
    expect(repo.taskSort, 'due');
    expect(repo.taskListSort, 'custom');
    expect(repo.taskDueTomorrowReminder, isTrue);

    // New shell defaults: Stream off, Today first, 24h clock.
    expect(repo.streamEnabled, isFalse);
    expect(repo.navOrderV2, [0, 1, 2, 3, 4]);
    expect(repo.time24h, isTrue);

    await repo.setBrightness('system');
    await repo.setStreamEnabled(true);
    await repo.setNavOrderV2([4, 0, 1, 2, 3]);
    await repo.setNavVersion(2);
    expect(repo.brightness, 'system');
    expect(repo.streamEnabled, isTrue);
    expect(repo.navOrderV2, [4, 0, 1, 2, 3]);
    expect(repo.navVersion, 2);

    await repo.setTaskDueTomorrowReminder(false);
    expect(repo.taskDueTomorrowReminder, isFalse);
    await repo.setTaskSort('name');
    await repo.setTaskListSort('created');
    expect(repo.taskSort, 'name');
    expect(repo.taskListSort, 'created');
  });
}
