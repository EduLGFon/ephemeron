part of '../event_repository.dart';

/// Prefix for local mirror rows imported from an OS calendar. Device keys are
/// not Google/Microsoft remote ids and must never be pushed to those services.
const String deviceImportRemoteIdPrefix = 'device:';

/// Local mirror persistence for OS calendar imports.
///
/// These rows are deliberately `dirty: false` and never enqueue outbox rows:
/// a refresh must not push device data to Google or Microsoft. A user edit
/// sets `dirty: true`, which makes later refreshes leave the row untouched.
mixin _EventDeviceImportOps on _EventRepositoryBase, _EventCalendarOps {
  Future<Event?> findImportedDeviceEvent({
    required String calendarId,
    required String remoteId,
  }) {
    return (dbSelect()
          ..where(
            (e) =>
                e.calendarId.equals(calendarId) & e.remoteId.equals(remoteId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// Inserts or refreshes one imported device event.
  ///
  /// Only remote-derived fields are written on update; local-only fields
  /// (alarms, reminders, visibility, colorId, createMeet) are preserved.
  /// A dirty row is left exactly as the user edited it.
  Future<void> upsertImportedDeviceEvent({
    required String calendarId,
    required String remoteId,
    required String title,
    String? notes,
    String? location,
    DateTime? startUtc,
    DateTime? endUtc,
    String? startDate,
    String? endDate,
    bool allDay = false,
    String? tzId,
    String? rrule,
    int? nowMs,
    List<String> attendeeEmails = const [],
  }) async {
    final now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final startMs = allDay ? null : startUtc?.toUtc().millisecondsSinceEpoch;
    final endMs = allDay ? null : endUtc?.toUtc().millisecondsSinceEpoch;
    final existing = await findImportedDeviceEvent(
      calendarId: calendarId,
      remoteId: remoteId,
    );
    if (existing == null) {
      final id = newId();
      await _db
          .into(_db.events)
          .insert(
            EventsCompanion.insert(
              id: id,
              calendarId: calendarId,
              title: Value(title),
              notes: Value(notes),
              location: Value(location),
              startUtc: Value(startMs),
              endUtc: Value(endMs),
              startDate: Value(allDay ? startDate : null),
              endDate: Value(allDay ? endDate : null),
              isAllDay: Value(allDay),
              tzId: Value(allDay ? null : tzId),
              rrule: Value(rrule),
              remoteId: Value(remoteId),
              dirty: const Value(false),
              googleAccount: const Value(null),
              microsoftAccount: const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (attendeeEmails.isNotEmpty) {
        await setAttendees(id, attendeeEmails);
      }
      return;
    }
    if (existing.dirty) return;
    await (_db.update(
      _db.events,
    )..where((e) => e.id.equals(existing.id))).write(
      EventsCompanion(
        title: Value(title),
        notes: Value(notes),
        location: Value(location),
        startUtc: Value(startMs),
        endUtc: Value(endMs),
        startDate: Value(allDay ? startDate : null),
        endDate: Value(allDay ? endDate : null),
        isAllDay: Value(allDay),
        tzId: Value(allDay ? null : tzId),
        rrule: Value(rrule),
        remoteId: Value(remoteId),
        googleAccount: const Value(null),
        microsoftAccount: const Value(null),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
    await setAttendees(existing.id, attendeeEmails);
    await _occ.invalidateEvent(existing.id);
  }

  /// Soft-deletes imported device rows in [calendarId] that are absent from
  /// [retainedRemoteIds]. Dirty rows and non-device remote ids are never
  /// touched, and rows are never hard-deleted.
  Future<int> reconcileImportedDeviceEvents({
    required String calendarId,
    required Set<String> retainedRemoteIds,
    required int nowMs,
  }) async {
    final rows =
        await (dbSelect()..where(
              (e) =>
                  e.calendarId.equals(calendarId) &
                  e.remoteId.like('$deviceImportRemoteIdPrefix%') &
                  e.deletedAt.isNull() &
                  e.dirty.equals(false),
            ))
            .get();
    var deleted = 0;
    for (final row in rows) {
      final remoteId = row.remoteId;
      if (remoteId == null || retainedRemoteIds.contains(remoteId)) continue;
      await (_db.update(_db.events)..where((e) => e.id.equals(row.id))).write(
        EventsCompanion(deletedAt: Value(nowMs), updatedAt: Value(nowMs)),
      );
      await _occ.invalidateEvent(row.id);
      deleted++;
    }
    return deleted;
  }
}
