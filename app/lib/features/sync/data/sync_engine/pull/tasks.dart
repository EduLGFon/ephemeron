part of '../../sync_engine.dart';

extension on SyncEngine {
  Future<int> _pullTasks(GoogleApiClient client) async {
    final lists = await (_db.select(
      _db.taskLists,
    )..where((l) => l.deletedAt.isNull())).get();
    debugPrint(
      '[sync] pulling ${lists.length} task lists '
      '(${lists.where((l) => l.remoteId != null).length} remote)',
    );
    var total = 0;
    for (final list in lists) {
      // Device-only lists have no remote counterpart; skip them instead
      // of querying Google with a local UUID (which 404s and fails sync).
      final remoteId = list.remoteId;
      if (remoteId == null) continue;
      if (!_pullableTaskList(list)) continue;
      var updatedMin = await _syncValue('tasks:${list.id}:updatedMin');
      try {
        var page = await client.tasksList(remoteId, updatedMin: updatedMin);
        if (updatedMin != null && page.items.isEmpty) {
          page = await client.tasksList(remoteId);
          debugPrint(
            '[sync] tasksList retry without updatedMin got ${page.items.length} items',
          );
        }
        debugPrint('[sync] tasksList got ${page.items.length} items');
        for (final g in page.items) {
          if (await _mergeTask(list, g)) total++;
        }
        if (page.nextUpdatedMin != null) {
          await _setSyncValue(
            'tasks:${list.id}:updatedMin',
            page.nextUpdatedMin!,
          );
        }
        await _setSyncMeta('tasks:${list.id}', error: null);
      } on GoogleApiException catch (e) {
        debugPrint('[sync] tasks pull failed status=${e.status}');
        // Keep rows for every failure. Auth, rate, network and server
        // failures are account-wide; 404/forbidden are list-only and must
        // not demand reconnect.
        late final String label;
        if (e.isAuthFailure) {
          _recordFailure(e);
          label = 'Google auth';
        } else if (e.isRateLimited) {
          _recordFailure(e);
          label = 'rate limited';
        } else if (e.isForbidden) {
          label = 'forbidden';
        } else if (e.status == 404) {
          label = 'Google 404';
        } else {
          _recordFailure(e);
          label = 'Google ${e.status}';
        }
        await _setSyncMeta('tasks:${list.id}', error: label);
      } on Exception catch (e) {
        debugPrint('[sync] tasks pull failed type=${e.runtimeType}');
        _recordFailure(e);
        await _setSyncMeta('tasks:${list.id}', error: 'sync failed');
      }
    }
    return total;
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
    final existing = await (_db.select(
      _db.tasks,
    )..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();
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
