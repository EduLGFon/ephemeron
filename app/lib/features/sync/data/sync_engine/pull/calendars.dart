part of '../../sync_engine.dart';

extension on SyncEngine {
  Future<int> _pullCalendars(GoogleApiClient client) async {
    await _cleanupLegacyCalendarTokens();
    final calendars =
        await (_db.select(_db.calendars)..where(
              (c) =>
                  c.source.equals('google') &
                  c.enabled.equals(true) &
                  c.deletedAt.isNull(),
            ))
            .get();
    debugPrint('[sync] pulling ${calendars.length} google calendars');
    var total = 0;
    for (final cal in calendars) {
      if (!await _pullableCalendar(cal)) continue;
      debugPrint('[sync] pulling calendar id=${cal.id} enabled=${cal.enabled}');
      final token = await _syncValue('cal:v2:${cal.id}:token');
      final remoteId = cal.remoteId;
      if (remoteId == null) {
        debugPrint('[sync] skip calendar with null remoteId');
        continue;
      }
      try {
        if (token == null) {
          total += await _fullCalendarResync(cal, client, keepDirty: true);
        } else {
          final page = await client.eventsList(remoteId, syncToken: token);
          debugPrint(
            '[sync] incremental pull got ${page.items.length} items (has remoteId=${cal.remoteId != null})',
          );
          total += await _mergeEvents(cal, page.items);
          if (page.nextSyncToken != null) {
            await _setSyncValue('cal:v2:${cal.id}:token', page.nextSyncToken!);
            // Best-effort cleanup of legacy token key.
            await (_db.delete(
              _db.syncState,
            )..where((s) => s.key.equals('cal:${cal.id}:token'))).go();
          }
        }
        await _setSyncMeta('cal:${cal.id}', error: null);
        // 404 stays enabled (fail-open) to avoid hiding shared calendars; transient
        // non-auth per-calendar failures are recorded in syncState meta and retried
        // next run instead of aborting the whole account.
      } on GoogleApiException catch (e) {
        debugPrint('[sync] calendar pull failed status=${e.status}');
        if (e.isGone) {
          // Drop the stale token before retrying: if the resync itself fails,
          // a surviving token would repeat 410 forever. A successful resync
          // writes a fresh token.
          await (_db.delete(
            _db.syncState,
          )..where((s) => s.key.equals('cal:v2:${cal.id}:token'))).go();
          // Full resync from inside a catch must not escape this calendar and
          // abort the remaining pull.
          try {
            total += await _fullCalendarResync(cal, client, keepDirty: true);
            await _setSyncMeta('cal:${cal.id}', error: null);
          } on Exception catch (retryError) {
            debugPrint(
              '[sync] calendar resync failed type=${retryError.runtimeType}',
            );
            _recordFailure(retryError);
            await _clearReaderClaim(remoteId);
            await _setSyncMeta('cal:${cal.id}', error: 'sync failed');
          }
        } else if (e.isAuthFailure) {
          _recordFailure(e);
          await _clearReaderClaim(remoteId);
          await _setSyncMeta('cal:${cal.id}', error: 'Google auth');
        } else if (e.isRateLimited) {
          _recordFailure(e);
          await _clearReaderClaim(remoteId);
          await _setSyncMeta('cal:${cal.id}', error: 'rate limited');
        } else if (e.isForbidden) {
          // Permanently inaccessible calendar (for example freeBusyReader or
          // a shared calendar this account cannot read). Record and skip; do
          // not demand reconnect for the whole account.
          await _clearReaderClaim(remoteId);
          await _setSyncMeta('cal:${cal.id}', error: 'forbidden');
        } else if (e.status == 404) {
          await _clearReaderClaim(remoteId);
          await _setSyncMeta('cal:${cal.id}', error: 'Google 404');
        } else {
          _recordFailure(e);
          await _clearReaderClaim(remoteId);
          await _setSyncMeta('cal:${cal.id}', error: 'Google ${e.status}');
        }
      } on Exception catch (e) {
        debugPrint('[sync] calendar pull failed type=${e.runtimeType}');
        _recordFailure(e);
        await _clearReaderClaim(remoteId);
        await _setSyncMeta('cal:${cal.id}', error: 'sync failed');
      }
    }
    return total;
  }

  Future<int> _fullCalendarResync(
    Calendar cal,
    GoogleApiClient client, {
    required bool keepDirty,
  }) async {
    final page = await client.eventsList(cal.remoteId ?? cal.id);
    debugPrint(
      '[sync] full resync got ${page.items.length} items (has remoteId=${cal.remoteId != null})',
    );
    return _db.transaction(() async {
      // Drop synced rows in the window; keep dirty local rows.
      final local =
          await (_db.select(_db.events)..where(
                (e) => e.calendarId.equals(cal.id) & e.deletedAt.isNull(),
              ))
              .get();
      for (final e in local) {
        if (e.remoteId != null && !(keepDirty && e.dirty)) {
          // Keep occurrence rows until the single post-pull rebuild replaces
          // the window atomically; deleting per calendar makes events flicker
          // out mid-sync.
          await (_db.delete(_db.events)..where((x) => x.id.equals(e.id))).go();
        }
      }
      final n = await _mergeEvents(cal, page.items);
      debugPrint('[sync] full resync merged $n events');
      if (page.nextSyncToken != null) {
        await _setSyncValue('cal:v2:${cal.id}:token', page.nextSyncToken!);
      }
      // Best-effort cleanup of legacy token key.
      await (_db.delete(
        _db.syncState,
      )..where((s) => s.key.equals('cal:${cal.id}:token'))).go();
      return n;
    });
  }
}
