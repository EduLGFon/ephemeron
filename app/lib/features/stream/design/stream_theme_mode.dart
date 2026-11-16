/// Stream-only theme mode. Persisted as a stable string key.
enum StreamThemeMode {
  system('system'),
  light('light'),
  dark('dark'),
  trueBlack('true_black');

  const StreamThemeMode(this.storageKey);

  final String storageKey;

  static StreamThemeMode parse(String? raw) => fromStorage(raw);

  static StreamThemeMode fromStorage(String? raw) {
    if (raw == null) return StreamThemeMode.system;
    for (final m in StreamThemeMode.values) {
      if (m.storageKey == raw) return m;
    }
    return StreamThemeMode.system;
  }
}
