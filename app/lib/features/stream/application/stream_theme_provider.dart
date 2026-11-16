import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stream_theme_preferences.dart';
import '../design/stream_theme_mode.dart';

final streamThemePreferencesProvider = Provider<StreamThemePreferences>((ref) {
  return StreamThemePreferences(() => SharedPreferences.getInstance());
});

// Override in tests with an injected getter.
final streamThemeProvider =
    NotifierProvider<StreamThemeNotifier, StreamThemeMode>(
      StreamThemeNotifier.new,
    );

class StreamThemeNotifier extends Notifier<StreamThemeMode> {
  bool _userChanged = false;

  @override
  StreamThemeMode build() {
    _load();
    return StreamThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = _preferences();
    final mode = await prefs.read();
    if (!_userChanged) state = mode;
  }

  StreamThemePreferences _preferences() {
    try {
      return ref.read(streamThemePreferencesProvider);
    } catch (_) {
      return StreamThemePreferences(() => SharedPreferences.getInstance());
    }
  }

  Future<void> setMode(StreamThemeMode mode) async {
    _userChanged = true;
    state = mode; // optimistic
    final prefs = _preferences();
    // ignore: unawaited_futures
    prefs.write(mode);
  }
}
