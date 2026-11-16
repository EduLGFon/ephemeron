/// Stream-only theme mode. Persisted as a stable string key.
/// See SUPER_TASK.md "DESIGN LANGUAGE" (themes).
enum StreamThemeMode {
  system('system'),
  light('light'),
  dark('dark'),
  trueBlack('true_black');

  const StreamThemeMode(this.storageKey);

  /// Stable storage key for this value.
  final String storageKey;

  /// Alias for [storageKey].
  String get key => storageKey;

  /// Alias for [storageKey].
  String get value => storageKey;

  /// Parse a stored value. Unknown or null maps to [system]. Never throws.
  static StreamThemeMode parse(String? raw) => fromStorage(raw);

  static StreamThemeMode fromStorage(String? raw) {
    if (raw == null) return StreamThemeMode.system;
    for (final m in StreamThemeMode.values) {
      if (m.storageKey == raw) return m;
    }
    return StreamThemeMode.system;
  }

  static StreamThemeMode fromString(String? raw) => fromStorage(raw);

  static StreamThemeMode fromKey(String? raw) => fromStorage(raw);
}

/// Top-level parse helper. Never throws.
StreamThemeMode streamThemeModeFromStorage(String? raw) =>
    StreamThemeMode.fromStorage(raw);

/// Top-level parse helper. Never throws.
StreamThemeMode parseStreamThemeMode(String? raw) =>
    StreamThemeMode.fromStorage(raw);
