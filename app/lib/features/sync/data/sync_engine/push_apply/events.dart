part of '../../sync_engine.dart';

extension on SyncEngine {
  Future<void> _applyEventOp(GoogleApiClient client, OutboxData op) async {
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
