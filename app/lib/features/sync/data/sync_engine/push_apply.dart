part of '../sync_engine.dart';

extension on SyncEngine {
  Future<void> _applyOp(GoogleApiClient client, OutboxData op) async {
    if (op.entity == 'event_remote') {
      final p = _opPayload(op);
      final calendarRemoteId = p['calendarRemoteId'] as String?;
      final eventRemoteId = p['eventRemoteId'] as String?;
      if (calendarRemoteId != null && eventRemoteId != null) {
        await client.eventDelete(calendarRemoteId, eventRemoteId);
      }
      return;
    }
    if (op.entity == 'task_remote') {
      final p = _opPayload(op);
      final listRemoteId = p['listRemoteId'] as String?;
      final taskRemoteId = p['taskRemoteId'] as String?;
      if (listRemoteId != null && taskRemoteId != null) {
        await client.taskDelete(listRemoteId, taskRemoteId);
      }
      return;
    }
    if (op.entity == 'event') {
      final e = await (_db.select(
        _db.events,
      )..where((t) => t.id.equals(op.entityId))).getSingleOrNull();
      // Deleted locally and purged: nothing to push.
      if (e == null) return;
      final calId = await _remoteCalendarId(e.calendarId) ?? e.calendarId;
      // Single-occurrence exceptions are separate Google instances; they
      // need their own delete/patch instead of touching the series master.
      if (e.recurringMasterId != null) {
        await _applyExceptionOp(client, e, calId);
        return;
      }
      if (op.op == 'delete' || e.deletedAt != null) {
        if (e.remoteId != null) {
          await client.eventDelete(calId, e.remoteId!);
        }
        return;
      }
      if (op.op == 'move' && e.remoteId != null) {
        final p = _opPayload(op);
        final fromRemote =
            p['fromRemoteCalendarId'] as String? ??
            (p['fromCalendarId'] == null
                ? null
                : await _remoteCalendarId(p['fromCalendarId'] as String));
        final destinationRemote = await _remoteCalendarId(e.calendarId);
        if (fromRemote != null &&
            destinationRemote != null &&
            fromRemote != destinationRemote) {
          final moved = await client.eventMove(
            fromRemote,
            e.remoteId!,
            destinationRemote,
          );
          await (_db.update(_db.events)..where((t) => t.id.equals(e.id))).write(
            EventsCompanion(
              remoteId: Value(moved['id'] as String? ?? e.remoteId),
              remoteEtag: Value(moved['etag'] as String?),
              dirty: const Value(false),
            ),
          );
          return;
        }
      }
      if (e.remoteId == null) {
        await _insertRemoteEvent(client, e, calId);
      } else {
        final body = await _eventBody(e);
        try {
          final updated = await client.eventPatch(
            calId,
            e.remoteId!,
            body,
            etag: e.remoteEtag,
          );
          await (_db.update(_db.events)..where((t) => t.id.equals(e.id))).write(
            EventsCompanion(
              remoteEtag: Value(updated['etag'] as String?),
              dirty: const Value(false),
            ),
          );
        } on GoogleApiException catch (err) {
          if (err.isConflict) {
            // Re-fetch series etag and re-apply intent, not blind overwrite.
            final page = await client.eventsList(
              calId,
              timeMin: _iso(_now() - 30 * msPerDay),
              timeMax: _iso(_now() + 90 * msPerDay),
            );
            final remote = page.items
                .where((m) => m['id'] == e.remoteId)
                .firstOrNull;
            if (remote == null) {
              final created = await client.eventInsert(calId, body);
              await (_db.update(
                _db.events,
              )..where((t) => t.id.equals(e.id))).write(
                EventsCompanion(
                  remoteId: Value(created['id'] as String?),
                  remoteEtag: Value(created['etag'] as String?),
                  dirty: const Value(false),
                ),
              );
            } else {
              final updated = await client.eventPatch(
                calId,
                e.remoteId!,
                body,
                etag: remote['etag'] as String?,
              );
              await (_db.update(
                _db.events,
              )..where((t) => t.id.equals(e.id))).write(
                EventsCompanion(
                  remoteEtag: Value(updated['etag'] as String?),
                  dirty: const Value(false),
                ),
              );
            }
          } else {
            rethrow;
          }
        }
      }
    } else if (op.entity == 'task') {
      final t = await (_db.select(
        _db.tasks,
      )..where((x) => x.id.equals(op.entityId))).getSingleOrNull();
      if (t == null) return;
      final listId = await _remoteTaskListId(t.listId) ?? '@default';
      if (op.op == 'delete' || t.deletedAt != null) {
        if (t.remoteId != null) {
          await client.taskDelete(listId, t.remoteId!);
        }
        return;
      }
      if (op.op == 'move' && t.remoteId != null) {
        final p = _opPayload(op);
        final fromRemote =
            p['fromRemoteListId'] as String? ??
            (p['fromListId'] == null
                ? null
                : await _remoteTaskListId(p['fromListId'] as String));
        final destinationRemote = await _remoteTaskListId(t.listId);
        if (fromRemote != null &&
            destinationRemote != null &&
            fromRemote != destinationRemote) {
          final moved = await client.taskMove(
            fromRemote,
            t.remoteId!,
            destinationRemote,
          );
          await (_db.update(_db.tasks)..where((x) => x.id.equals(t.id))).write(
            TasksCompanion(
              remoteId: Value(moved['id'] as String? ?? t.remoteId),
              remoteEtag: Value(moved['etag'] as String?),
              dirty: const Value(false),
            ),
          );
          return;
        }
      }
      if (t.remoteId == null) {
        final created = await client.taskInsert(listId, taskToGoogle(t));
        await (_db.update(_db.tasks)..where((x) => x.id.equals(t.id))).write(
          TasksCompanion(
            remoteId: Value(created['id'] as String?),
            remoteEtag: Value(created['etag'] as String?),
            dirty: const Value(false),
          ),
        );
      } else {
        final updated = await client.taskPatch(
          listId,
          t.remoteId!,
          taskToGoogle(t),
          etag: t.remoteEtag,
        );
        await (_db.update(_db.tasks)..where((x) => x.id.equals(t.id))).write(
          TasksCompanion(
            remoteEtag: Value(updated['etag'] as String?),
            dirty: const Value(false),
          ),
        );
      }
    } else if (op.entity == 'task_list') {
      final list = await (_db.select(
        _db.taskLists,
      )..where((l) => l.id.equals(op.entityId))).getSingleOrNull();
      if (list == null) return;
      if (op.op == 'delete' || list.deletedAt != null) {
        if (list.remoteId != null) {
          await client.taskListDelete(list.remoteId!);
        }
        await _hardDeleteTaskList(list.id);
        return;
      }
      if (list.remoteId == null) {
        final created = await client.taskListCreate(list.name);
        await (_db.update(
          _db.taskLists,
        )..where((l) => l.id.equals(list.id))).write(
          TaskListsCompanion(
            remoteId: Value(created['id'] as String?),
            remoteEtag: Value(created['etag'] as String?),
            dirty: const Value(false),
          ),
        );
      } else {
        final updated = await client.taskListPatch(list.remoteId!, list.name);
        await (_db.update(
          _db.taskLists,
        )..where((l) => l.id.equals(list.id))).write(
          TaskListsCompanion(
            remoteEtag: Value(updated['etag'] as String?),
            dirty: const Value(false),
          ),
        );
      }
    }
  }

  /// Pushes one single-occurrence exception. Google addresses an overridden
  /// instance by its own event id, so a local exception first resolves the
  /// matching generated instance when it has never been synced.
  Future<void> _applyExceptionOp(
    GoogleApiClient client,
    Event e,
    String calId,
  ) async {
    final masterId = e.recurringMasterId;
    if (masterId == null) return;
    final master = await (_db.select(
      _db.events,
    )..where((t) => t.id.equals(masterId))).getSingleOrNull();
    if (master == null) return;
    // The instance cannot be looked up until the series exists remotely.
    var masterRemoteId = master.remoteId;
    if (masterRemoteId == null) {
      masterRemoteId = await _insertRemoteEvent(client, master, calId);
      if (masterRemoteId == null) {
        throw GoogleApiException(500, 'Google insert returned no id');
      }
    }
    if (e.deletedAt != null || e.status == 'cancelled') {
      await _pushExceptionDelete(client, e, calId, masterRemoteId);
    } else {
      await _pushExceptionPatch(client, e, calId, masterRemoteId);
    }
  }

  /// Deletes the Google instance for a cancelled/deleted exception.
  Future<void> _pushExceptionDelete(
    GoogleApiClient client,
    Event e,
    String calId,
    String masterRemoteId,
  ) async {
    final instance = await _exceptionInstance(client, e, calId, masterRemoteId);
    if (instance != null) {
      try {
        await client.eventDelete(calId, instance.id);
      } on GoogleApiException catch (err) {
        // Already gone: the local cancelled row is the desired state, so
        // clear the op instead of retrying a 410/404 forever.
        if (err.status != 404 && err.status != 410) rethrow;
      }
    }
    await (_db.update(_db.events)..where((t) => t.id.equals(e.id))).write(
      EventsCompanion(
        remoteId: const Value(null),
        remoteEtag: const Value(null),
        dirty: const Value(false),
        updatedAt: Value(_now()),
      ),
    );
  }

  /// Patches the Google instance for a confirmed exception, retrying once
  /// with a fresh etag after a conflict.
  Future<void> _pushExceptionPatch(
    GoogleApiClient client,
    Event e,
    String calId,
    String masterRemoteId,
  ) async {
    var instance = await _exceptionInstance(client, e, calId, masterRemoteId);
    if (instance == null) {
      throw GoogleApiException(503, 'Google instance not found');
    }
    final body = await _eventBody(e);
    try {
      final updated = await client.eventPatch(
        calId,
        instance.id,
        body,
        etag: instance.etag,
      );
      await _saveExceptionPatch(e, updated, instance.id);
    } on GoogleApiException catch (err) {
      if (!err.isConflict) rethrow;
      instance = await _resolveExceptionInstance(
        client,
        calId,
        masterRemoteId,
        e.originalStart,
      );
      if (instance == null) {
        throw GoogleApiException(503, 'Google instance not found');
      }
      final updated = await client.eventPatch(
        calId,
        instance.id,
        body,
        etag: instance.etag,
      );
      await _saveExceptionPatch(e, updated, instance.id);
    }
  }

  Future<void> _saveExceptionPatch(
    Event e,
    Map<String, dynamic> updated,
    String fallbackId,
  ) async {
    await (_db.update(_db.events)..where((t) => t.id.equals(e.id))).write(
      EventsCompanion(
        remoteId: Value(updated['id'] as String? ?? fallbackId),
        remoteEtag: Value(updated['etag'] as String?),
        dirty: const Value(false),
        updatedAt: Value(_now()),
      ),
    );
  }

  /// Uses the exception's own instance id when known, otherwise resolves the
  /// generated instance for its original occurrence.
  Future<({String id, String? etag})?> _exceptionInstance(
    GoogleApiClient client,
    Event e,
    String calId,
    String masterRemoteId,
  ) async {
    final remoteId = e.remoteId;
    if (remoteId != null) return (id: remoteId, etag: e.remoteEtag);
    return _resolveExceptionInstance(
      client,
      calId,
      masterRemoteId,
      e.originalStart,
    );
  }

  /// Finds the Google instance id/etag for an original occurrence.
  Future<({String id, String? etag})?> _resolveExceptionInstance(
    GoogleApiClient client,
    String calId,
    String masterRemoteId,
    int? originalStart,
  ) async {
    if (originalStart == null) return null;
    final page = await client.eventsList(
      calId,
      timeMin: _iso(originalStart - msPerDay),
      timeMax: _iso(originalStart + msPerDay),
      singleEvents: true,
      showDeleted: true,
    );
    for (final item in page.items) {
      if (item['recurringEventId'] != masterRemoteId) continue;
      if (originalStartMsFromGoogle(item) != originalStart) continue;
      final id = item['id'] as String?;
      if (id == null) continue;
      return (id: id, etag: item['etag'] as String?);
    }
    return null;
  }

  /// Serializes an event with its attendees for Google patches/inserts.
  Future<Map<String, dynamic>> _eventBody(Event e) async {
    final body = eventToGoogle(e);
    final atts = await (_db.select(
      _db.eventAttendees,
    )..where((a) => a.eventId.equals(e.id))).get();
    if (atts.isNotEmpty) {
      body['attendees'] = atts.map((a) => {'email': a.email}).toList();
    }
    return body;
  }

  /// Inserts [e] and persists the returned remote id/etag. Shared by normal
  /// creates and by exception pushes that must materialize a local master.
  Future<String?> _insertRemoteEvent(
    GoogleApiClient client,
    Event e,
    String calId,
  ) async {
    final body = await _eventBody(e);
    final created = await client.eventInsert(calId, body);
    final remoteId = created['id'] as String?;
    await (_db.update(_db.events)..where((t) => t.id.equals(e.id))).write(
      EventsCompanion(
        remoteId: Value(remoteId),
        remoteEtag: Value(created['etag'] as String?),
        dirty: const Value(false),
      ),
    );
    return remoteId;
  }
}
