import 'package:shared_preferences/shared_preferences.dart';

import '../design/stream_theme_mode.dart';

/// Thin persistence wrapper for [StreamThemeMode].
class StreamThemePreferences {
  StreamThemePreferences(this._prefsGetter);

  final Future<SharedPreferences> Function() _prefsGetter;

  static const String storageKey = 'stream.themeMode';

  Future<StreamThemeMode> read() async {
    try {
      final prefs = await _prefsGetter();
      return StreamThemeMode.fromStorage(prefs.getString(storageKey));
    } catch (_) {
      return StreamThemeMode.system;
    }
  }

  Future<void> write(StreamThemeMode mode) async {
    final prefs = await _prefsGetter();
    await prefs.setString(storageKey, mode.storageKey);
  }
}
