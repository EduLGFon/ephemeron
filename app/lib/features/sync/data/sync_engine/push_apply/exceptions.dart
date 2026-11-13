part of '../../sync_engine.dart';

extension on SyncEngine {
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
}
