import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logger/logger.dart' show AppLogger;
import 'stream_theme_preferences.dart';
import '../design/stream_theme_mode.dart';

final streamThemePreferencesProvider = Provider<StreamThemePreferences>((ref) {
  return StreamThemePreferences(() => SharedPreferences.getInstance());
});

final streamThemeProvider =
    NotifierProvider<StreamThemeNotifier, StreamThemeMode>(
      StreamThemeNotifier.new,
    );

class StreamThemeNotifier extends Notifier<StreamThemeMode> {
  final AppLogger _log = AppLogger();
  bool _userChanged = false;
  bool _disposed = false;

  @override
  StreamThemeMode build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return StreamThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = ref.read(streamThemePreferencesProvider);
    final mode = await prefs.read();
    if (!_disposed && !_userChanged) state = mode;
  }

  Future<void> setMode(StreamThemeMode mode) async {
    _userChanged = true;
    state = mode;
    final prefs = ref.read(streamThemePreferencesProvider);
    try {
      await prefs.write(mode);
    } catch (e) {
      _log.error('stream theme persist failed', e);
      // keep optimistic state
    }
  }
}
