part of '../../sync_engine.dart';

const _calendarGoneCooldownMs = 60 * 60 * 1000;

extension on SyncEngine {
  Future<String?> _remoteCalendarId(String localId) async {
    final cal = await (_db.select(
      _db.calendars,
    )..where((c) => c.id.equals(localId))).getSingleOrNull();
    return cal?.remoteId;
  }

  Future<String?> _remoteTaskListId(String? localId) async {
    if (localId == null) return null;
    final list = await (_db.select(
      _db.taskLists,
    )..where((l) => l.id.equals(localId))).getSingleOrNull();
    return list?.remoteId;
  }

  Future<String?> _syncValue(String key) async {
    final row = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setSyncValue(String key, String value) async {
    final now = _now();
    await _db
        .into(_db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(
            key: key,
            value: Value(value),
            lastSyncAt: Value(now),
          ),
        );
  }

  Future<void> _setSyncMeta(String key, {String? error}) async {
    await _db
        .into(_db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(
            key: '$key:meta',
            lastSyncAt: Value(_now()),
            lastError: Value(error),
          ),
        );
  }

  String _calendarGoneAtKey(String calendarId) => 'cal:v2:$calendarId:goneAt';

  Future<bool> _isCalendarGoneCooldownActive(String calendarId) async {
    final raw = await _syncValue(_calendarGoneAtKey(calendarId));
    if (raw == null) return false;
    final at = int.tryParse(raw);
    if (at == null) return false;
    return _now() - at < _calendarGoneCooldownMs;
  }

  Future<void> _clearCalendarGoneAt(String calendarId) async {
    await (_db.delete(
      _db.syncState,
    )..where((s) => s.key.equals(_calendarGoneAtKey(calendarId)))).go();
  }
}
