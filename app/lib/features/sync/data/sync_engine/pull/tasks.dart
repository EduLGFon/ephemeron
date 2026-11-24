part of '../../sync_engine.dart';

extension on SyncEngine {
  Future<({int lists, int tasks})> _pullTasks(GoogleApiClient client) async {
    final lists = await (_db.select(
      _db.taskLists,
    )..where((l) => l.deletedAt.isNull())).get();
    var total = 0;
    for (final list in lists) {
      // Device-only lists have no remote counterpart; skip them instead
      // of querying Google with a local UUID (which 404s and fails sync).
      final remoteId = list.remoteId;
      if (remoteId == null) continue;
      if (!_pullableTaskList(list)) continue;

      final key = 'tasks:${list.id}:updatedMin';
      final oldCursor = await _syncValue(key);
      // A bounded safety net is only for a list that has a cursor but no
      // live local rows. Count before the pull so a page that returns items
      // is merged without a redundant full fetch. It is never keyed on an
      // empty page alone (that made every no-change sync refetch).
      final liveCount = _db.tasks.id.count();
      final countRow =
          await (_db.selectOnly(_db.tasks)
                ..addColumns([liveCount])
                ..where(
                  _db.tasks.listId.equals(list.id) &
                      _db.tasks.deletedAt.isNull(),
                ))
              .getSingle();
      final localEmpty = (countRow.read(liveCount) ?? 0) == 0;

      TasksPage page;
      var cursor = oldCursor;
      var fullFetch = false;
      try {
        page = await client.tasksList(remoteId, updatedMin: cursor);
      } catch (e) {
        // A bad `updatedMin` (Google 400/410) is the only reason to discard
        // the cursor. Do exactly one full fetch, then store a fresh cursor.
        if (e is GoogleApiException &&
            cursor != null &&
            _isInvalidTaskCursor(e.status)) {
          cursor = null; // ignore the bad cursor
          try {
            page = await client.tasksList(remoteId);
            fullFetch = true;
            if (_verboseSyncLog) {
              debugPrint(
                '[sync] tasksList cursor retry got ${page.items.length} items',
              );
            }
          } catch (retryError) {
            await _recordTaskPullError(list, retryError);
            continue;
          }
        } else {
          await _recordTaskPullError(list, e);
          continue;
        }
      }

      // Local state is clearly empty while a cursor exists: at most one
      // bounded full fetch per list per run, and only when the incremental
      // page yielded nothing. Not done on every empty page.
      if (!fullFetch && oldCursor != null && page.items.isEmpty && localEmpty) {
        try {
          page = await client.tasksList(remoteId);
          fullFetch = true;
          if (_verboseSyncLog) {
            debugPrint(
              '[sync] tasksList empty-state retry got ${page.items.length} items',
            );
          }
        } catch (retryError) {
          await _recordTaskPullError(list, retryError);
          continue;
        }
      }

      if (_verboseSyncLog) {
        debugPrint('[sync] tasksList got ${page.items.length} items');
      }
      for (final g in page.items) {
        if (await _mergeTask(list, g)) total++;
      }
      await _setTaskCursor(key, cursor, page.nextUpdatedMin);
      await _setSyncMeta('tasks:${list.id}', error: null);
    }
    return (lists: lists.length, tasks: total);
  }

  /// Whether [status] signals an unusable `updatedMin` cursor.
  static bool _isInvalidTaskCursor(int status) =>
      status == 400 || status == 410;

  /// Persists [candidate] only when it does not move [current] backwards.
  /// A null [current] (first pull, or a discarded bad cursor) always accepts
  /// it. Cursors are RFC3339 UTC strings; on a failed fetch there is no call
  /// here at all, so a failure never advances the stored value.
  Future<void> _setTaskCursor(
    String key,
    String? current,
    String? candidate,
  ) async {
    if (candidate == null) return;
    if (current != null) {
      final prev = DateTime.tryParse(current);
      final next = DateTime.tryParse(candidate);
      if (prev != null && next != null && next.isBefore(prev)) {
        if (_verboseSyncLog) {
          debugPrint('[sync] tasksList cursor kept (would regress)');
        }
        return;
      }
    }
    await _setSyncValue(key, candidate);
  }

  /// Records a task-pull failure without touching the stored cursor or rows.
  /// Failure labels are fixed; no task content or ids are logged.
  Future<void> _recordTaskPullError(TaskList list, Object error) async {
    if (error is GoogleApiException) {
      debugPrint('[sync] tasks pull failed${_syncErrorLogSuffix(error)}');
      // Keep rows for every failure. Auth, rate, network and server
      // failures are account-wide; 404/forbidden are list-only and must
      // not demand reconnect.
      late final String label;
      if (error.isAuthFailure) {
        _recordFailure(error);
        label = 'Google auth';
      } else if (error.isRateLimited) {
        _recordFailure(error);
        label = 'rate limited';
      } else if (error.isForbidden) {
        label = 'forbidden';
      } else if (error.status == 404) {
        label = 'Google 404';
      } else {
        _recordFailure(error);
        label = 'Google ${error.status}';
      }
      await _setSyncMeta('tasks:${list.id}', error: label);
    } else {
      debugPrint('[sync] tasks pull failed${_syncErrorLogSuffix(error)}');
      _recordFailure(error);
      await _setSyncMeta('tasks:${list.id}', error: 'sync failed');
    }
  }

  /// Whether [list] may be pulled under the active account. Same rule as
  /// calendars: stamped rows belong to their account's loop, null-stamped
  /// rows absent from this run's discovery belong elsewhere.
  bool _pullableTaskList(TaskList list) {
    if (account == null) return true;
    if (list.googleAccount != null) return list.googleAccount == account;
    final ids = _accountListIds;
    if (ids == null) return true;
    return ids.contains(list.remoteId);
  }

  Future<bool> _mergeTask(TaskList list, Map<String, dynamic> g) async {
    final remoteId = g['id'] as String?;
    if (remoteId == null) return false;
    final matches = await (_db.select(
      _db.tasks,
    )..where((t) => t.remoteId.equals(remoteId))).get();
    // Google task ids are unique per list, not globally. Match only a row
    // owned by this account (or an unstamped legacy row) and never throw when
    // stale duplicates exist. A row owned by another account is left alone so
    // this pull cannot overwrite it.
    final candidates = matches.where(
      (t) => t.googleAccount == null || t.googleAccount == account,
    );
    final Task? existing = candidates.isEmpty ? null : candidates.first;
    if (existing == null) {
      final mapped = taskFromGoogle(g, list.id, newId());
      await _db
          .into(_db.tasks)
          .insert(mapped.companion.copyWith(googleAccount: Value(account)));
      return true;
    } else if (!existing.dirty) {
      final mapped = taskFromGoogle(g, list.id, existing.id);
      // Preserve local-only fields: dueTime, priority, tags stay.
      await (_db.update(
        _db.tasks,
      )..where((t) => t.id.equals(existing.id))).write(
        mapped.companion.copyWith(
          dueTime: Value(existing.dueTime),
          priority: Value(existing.priority),
          durationMin: Value(existing.durationMin),
          rrule: Value(existing.rrule),
          plannedStart: Value(existing.plannedStart),
          plannedEnd: Value(existing.plannedEnd),
          seriesId: Value(existing.seriesId),
          recurrenceKey: Value(existing.recurrenceKey),
        ),
      );
      return true;
    }
    return false;
  }
}
