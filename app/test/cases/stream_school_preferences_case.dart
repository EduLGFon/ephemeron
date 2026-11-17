import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/stream/application/stream_school_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to not completed when nothing is stored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    expect(StreamSchoolPreferences(prefs).hasCompleted, isFalse);
  });

  test('key is stable and drives the stored value', () async {
    expect(StreamSchoolPreferences.completedKey, 'stream.school.completed');
    SharedPreferences.setMockInitialValues(<String, Object>{
      StreamSchoolPreferences.completedKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    expect(StreamSchoolPreferences(prefs).hasCompleted, isTrue);
  });

  test('markCompleted persists true and reset persists false', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final school = StreamSchoolPreferences(prefs);

    await school.markCompleted();
    expect(school.hasCompleted, isTrue);
    expect(prefs.getBool(StreamSchoolPreferences.completedKey), isTrue);

    await school.reset();
    expect(school.hasCompleted, isFalse);
    expect(prefs.getBool(StreamSchoolPreferences.completedKey), isFalse);
  });

  test('a second instance reads the persisted value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await StreamSchoolPreferences(prefs).markCompleted();

    final reloaded = await SharedPreferences.getInstance();
    expect(StreamSchoolPreferences(reloaded).hasCompleted, isTrue);
  });

  test('provider exposes the persisted value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      StreamSchoolPreferences.completedKey: true,
    });
    final container = await _container();
    addTearDown(container.dispose);

    expect(await container.read(streamSchoolCompletedProvider.future), isTrue);
  });

  test('provider updates state and storage on mark and reset', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = await _container(prefs);
    addTearDown(container.dispose);
    expect(await container.read(streamSchoolCompletedProvider.future), isFalse);

    final notifier = container.read(streamSchoolCompletedProvider.notifier);
    await notifier.markCompleted();
    expect(container.read(streamSchoolCompletedProvider).value, isTrue);
    expect(prefs.getBool(StreamSchoolPreferences.completedKey), isTrue);

    await notifier.reset();
    expect(container.read(streamSchoolCompletedProvider).value, isFalse);
    expect(prefs.getBool(StreamSchoolPreferences.completedKey), isFalse);
  });
}

Future<ProviderContainer> _container([SharedPreferences? prefs]) async {
  final resolved = prefs ?? await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) async => resolved),
    ],
  );
}
