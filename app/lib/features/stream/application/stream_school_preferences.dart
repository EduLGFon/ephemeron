import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/application/settings_providers.dart';

/// Persists whether the Gesture School has been completed.
///
/// Holds a single boolean flag. No personal data is involved.
class StreamSchoolPreferences {
  StreamSchoolPreferences(this._prefs);

  final SharedPreferences _prefs;

  /// SharedPreferences key for the completion flag.
  ///
  /// Compatibility-sensitive: installed apps keep this value across releases.
  /// Renaming the key would lose completion state and replay the school.
  static const String completedKey = 'stream.school.completed';

  /// Whether the school has been completed. Defaults to false when unset.
  bool get hasCompleted => _prefs.getBool(completedKey) ?? false;

  Future<void> markCompleted() => _prefs.setBool(completedKey, true);

  Future<void> reset() => _prefs.setBool(completedKey, false);
}

/// Preferences backed by the app's shared [SharedPreferences] instance.
final streamSchoolPreferencesProvider = FutureProvider<StreamSchoolPreferences>(
  (ref) async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return StreamSchoolPreferences(prefs);
  },
);

/// Completion flag for the Gesture School, persisted across launches.
final streamSchoolCompletedProvider =
    AsyncNotifierProvider<StreamSchoolCompletedNotifier, bool>(
      StreamSchoolCompletedNotifier.new,
    );

class StreamSchoolCompletedNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(streamSchoolPreferencesProvider.future);
    return prefs.hasCompleted;
  }

  Future<void> markCompleted() => _persist(completed: true);

  Future<void> reset() => _persist(completed: false);

  /// Persists first so state never claims a write that failed.
  Future<void> _persist({required bool completed}) async {
    final prefs = await ref.read(streamSchoolPreferencesProvider.future);
    if (completed) {
      await prefs.markCompleted();
    } else {
      await prefs.reset();
    }
    if (ref.mounted) state = AsyncData(completed);
  }
}
