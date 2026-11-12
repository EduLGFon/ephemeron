part of '../../sync_engine.dart';

extension on SyncEngine {
  // Discovery: mirror the remote calendar/task-list catalog locally so
  // the first sync after sign-in has something to pull into. Local-only
  // rows are never touched; renamed remotes update in place when clean.

  Future<(int, int)> _syncCalendarList(GoogleApiClient client) async {
    final remote = await client.calendarList();
    debugPrint('[sync] calendarList returned ${remote.length} items');
    _accountCalendarIds = {
      for (final c in remote) c['id'] as String?,
    }.whereType<String>().toSet();
    _readableCalendarIds = {
      for (final c in remote)
        if (c['deleted'] != true && c['accessRole'] != 'freeBusyReader')
          c['id'] as String?,
    }.whereType<String>().toSet();
    final now = _now();
    var created = 0;
    for (final c in remote) {
      final id = c['id'] as String?;
      if (id == null || c['deleted'] == true) continue;
      final name = (c['summary'] as String?)?.trim();
      final accessRole = c['accessRole'] as String?;
      final readOnly = _isReadOnlyRole(accessRole);
      final linkedRows = await (_db.select(
        _db.calendars,
      )..where((t) => t.remoteId.equals(id))).get();
      var existing = linkedRows.firstOrNull;
      // Repair legacy rows created before remoteId was persisted.
      if (existing == null && name != null && name.isNotEmpty) {
        final legacyRows =
            await (_db.select(_db.calendars)..where(
                  (t) =>
                      t.source.equals('google') &
                      t.remoteId.isNull() &
                      t.name.equals(name),
                ))
                .get();
        existing = legacyRows.firstOrNull;
        if (existing != null) {
          await (_db.update(
            _db.calendars,
          )..where((t) => t.id.equals(existing!.id))).write(
            CalendarsCompanion(
              remoteId: Value(id),
              updatedAt: Value(now),
              googleAccount: Value(account),
            ),
          );
          debugPrint(
            '[sync] repaired legacy calendar remoteId id=${existing.id}',
          );
        }
      }
      if (existing == null) {
        await _db
            .into(_db.calendars)
            .insert(
              CalendarsCompanion.insert(
                id: newId(),
                remoteId: Value(id),
                name: (name == null || name.isEmpty) ? id : name,
                color: Value(_calendarColorOf(c)),
                source: const Value('google'),
                googleAccount: Value(account),
                readOnly: Value(readOnly),
                createdAt: now,
                updatedAt: now,
              ),
            );
        created++;
      } else {
        // Do not steal a shared calendar already stamped to another signed-in
        // account. Only null or unknown owners are (re)stamped.
        final owner = existing.googleAccount;
        if (account != null && (owner == null || !_ownerIsSignedIn(owner))) {
          await (_db.update(
            _db.calendars,
          )..where((t) => t.id.equals(existing!.id))).write(
            CalendarsCompanion(
              googleAccount: Value(account),
              updatedAt: Value(now),
            ),
          );
        }
        if (accessRole != null && existing.readOnly != readOnly) {
          await (_db.update(
            _db.calendars,
          )..where((t) => t.id.equals(existing!.id))).write(
            CalendarsCompanion(
              readOnly: Value(readOnly),
              updatedAt: Value(now),
            ),
          );
        }
        if (!existing.dirty && name != null && name.isNotEmpty) {
          final color = _calendarColorOf(c);
          final update = CalendarsCompanion(
            name: Value(name),
            updatedAt: Value(now),
            color: color == null ? const Value.absent() : Value(color),
          );
          if (existing.name != name || existing.color != color) {
            await (_db.update(
              _db.calendars,
            )..where((t) => t.id.equals(existing!.id))).write(update);
          }
        }
      }
    }
    // Remove duplicate google calendars left by earlier (buggy) runs. Keep
    // one row per remoteId, reassign events from duplicates to the kept row
    // inside a transaction so no events are orphaned, then delete duplicates.
    final all = await (_db.select(
      _db.calendars,
    )..where((c) => c.source.equals('google'))).get();
    final byRemote = <String, List<Calendar>>{};
    for (final c in all) {
      final key = c.remoteId;
      if (key == null) continue;
      byRemote.putIfAbsent(key, () => []).add(c);
    }
    await _db.transaction(() async {
      for (final entry in byRemote.entries) {
        final rows = entry.value;
        if (rows.length <= 1) continue;
        // Prefer an active row over a tombstone/disabled one; then oldest.
        final kept = rows.reduce((a, b) {
          final aDeleted = a.deletedAt != null;
          final bDeleted = b.deletedAt != null;
          if (aDeleted != bDeleted) return aDeleted ? b : a;
          final aEnabled = a.enabled;
          final bEnabled = b.enabled;
          if (aEnabled != bEnabled) return aEnabled ? a : b;
          if (a.createdAt != b.createdAt) {
            return a.createdAt < b.createdAt ? a : b;
          }
          return a.id.compareTo(b.id) <= 0 ? a : b;
        });
        for (final dup in rows) {
          if (dup.id == kept.id) continue;
          await (_db.update(_db.events)
                ..where((e) => e.calendarId.equals(dup.id)))
              .write(EventsCompanion(calendarId: Value(kept.id)));
          // Drop stale sync tokens/meta for the removed duplicate.
          await (_db.delete(
            _db.syncState,
          )..where((s) => s.key.equals('cal:${dup.id}:token'))).go();
          await (_db.delete(
            _db.syncState,
          )..where((s) => s.key.equals('cal:${dup.id}:meta'))).go();
          await (_db.delete(
            _db.syncState,
          )..where((s) => s.key.equals('cal:v2:${dup.id}:token'))).go();
          await (_db.delete(
            _db.syncState,
          )..where((s) => s.key.equals('cal:v2:${dup.id}:meta'))).go();
          await (_db.delete(
            _db.calendars,
          )..where((x) => x.id.equals(dup.id))).go();
        }
      }
    });
    return (remote.length, created);
  }

  Future<(int, int)> _syncTaskLists(GoogleApiClient client) async {
    List<Map<String, dynamic>> remote;
    try {
      remote = await client.taskLists();
    } on GoogleApiException catch (e) {
      debugPrint('[sync] taskLists discovery failed status=${e.status}');
      // 404 and forbidden 403 are list-only: the token/account is fine, so do
      // not demand reconnect or mark the whole run as failed. Auth, rate,
      // server and other statuses stay global failures.
      if (e.status != 404 && !e.isForbidden) _recordFailure(e);
      await _setSyncMeta('tasks', error: 'Google ${e.status}');
      return (0, 0);
    } catch (e) {
      debugPrint('[sync] taskLists discovery failed type=${e.runtimeType}');
      _recordFailure(e);
      await _setSyncMeta('tasks', error: 'sync failed');
      return (0, 0);
    }
    debugPrint('[sync] taskLists returned ${remote.length} items');
    _accountListIds = account == null
        ? null
        : {
            for (final l in remote) l['id'] as String?,
          }.whereType<String>().toSet();
    final now = _now();
    var created = 0;
    for (final l in remote) {
      final id = l['id'] as String?;
      if (id == null) continue;
      final name = (l['title'] as String?)?.trim();
      // A remote id belongs to exactly one local row. Duplicate rows from
      // older runs must not make discovery throw or insert another copy.
      final linked = await (_db.select(
        _db.taskLists,
      )..where((t) => t.remoteId.equals(id))).get();
      final existing = linked.where((row) => row.deletedAt == null).firstOrNull;
      if (existing == null) {
        if (linked.isNotEmpty) {
          // The only local copy is a tombstone awaiting remote delete. Do not
          // resurrect it; the queued delete (or the next sync) owns it.
          continue;
        }
        await _db
            .into(_db.taskLists)
            .insert(
              TaskListsCompanion.insert(
                id: newId(),
                remoteId: Value(id),
                name: (name == null || name.isEmpty) ? id : name,
                googleAccount: Value(account),
                createdAt: now,
                updatedAt: now,
              ),
            );
        created++;
      } else {
        final owner = existing.googleAccount;
        if (account != null && (owner == null || !_ownerIsSignedIn(owner))) {
          await (_db.update(
            _db.taskLists,
          )..where((t) => t.id.equals(existing.id))).write(
            TaskListsCompanion(
              googleAccount: Value(account),
              updatedAt: Value(now),
            ),
          );
        }
        if (!existing.dirty && name != null && name.isNotEmpty) {
          await (_db.update(
            _db.taskLists,
          )..where((t) => t.id.equals(existing.id))).write(
            TaskListsCompanion(name: Value(name), updatedAt: Value(now)),
          );
        }
      }
    }
    return (remote.length, created);
  }

  static bool _isReadOnlyRole(String? role) =>
      role == 'reader' || role == 'freeBusyReader';

  /// Google calendarList color: backgroundColor hex wins, colorId palette
  /// id as fallback. Returns null when the entry carries no color so the
  /// occurrence builder can apply its stable per-calendar fallback.
  String? _calendarColorOf(Map<String, dynamic> c) {
    final bg = c['backgroundColor'] as String?;
    if (bg != null && bg.isNotEmpty) return bg;
    final id = c['colorId'] as String?;
    if (id != null && id.isNotEmpty) return id;
    return null;
  }
}
