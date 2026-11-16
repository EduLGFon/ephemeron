part of '../event_repository.dart';

mixin _EventOccurrenceOps
    on
        _EventRepositoryBase,
        _EventOccurrenceExceptionOps,
        _EventOccurrenceSplitOps {
  Future<void> deleteOccurrence(
    String masterId,
    DateTime originalStartUtc, {
    required EditScope scope,
  }) async {
    final master = await _master(masterId);
    await _assertEventWritable(master);
    final cutMs = originalStartUtc.toUtc().millisecondsSinceEpoch;
    switch (scope) {
      case EditScope.single:
        final exId = await _upsertException(
          master,
          cutMs,
          const EventsCompanion(status: Value('cancelled')),
        );
        await _enqueue(exId, 'delete');
      case EditScope.following:
        final first = _seriesFirstStart(master);
        if (first != null && cutMs <= first) {
          await deleteEvent(masterId);
          return;
        }
        await _truncateMaster(master, cutMs);
        await _enqueue(masterId, 'update');
      case EditScope.all:
        await deleteEvent(masterId);
    }
    await _occ.invalidateEvent(masterId);
  }

  Future<String> editOccurrence(
    String masterId,
    DateTime originalStartUtc, {
    required EditScope scope,
    String? title,
    DateTime? startUtc,
    DateTime? endUtc,
    String? startDate,
    String? endDate,
    String? location,
    String? meetUrl,
    String? visibility,
    String? transparency,
    String? colorId,
    String? tzId,
    bool? createMeet,
    String? Function()? rrule,
    bool resetExceptions = false,
    String? Function()? reminders,
    String? Function()? alarmPreset,
    String? Function()? notes,
    bool syncLinkedDate = true,
  }) async {
    final master = await _master(masterId);
    await _assertEventWritable(master);
    final cutMs = originalStartUtc.toUtc().millisecondsSinceEpoch;
    final notePatch = notes == null
        ? const Value<String?>.absent()
        : Value<String?>(notes());
    String affectedId;
    switch (scope) {
      case EditScope.single:
        affectedId = await _upsertException(
          master,
          cutMs,
          EventsCompanion(
            title: title == null ? const Value.absent() : Value(title),
            startUtc: startUtc == null
                ? const Value.absent()
                : Value(startUtc.toUtc().millisecondsSinceEpoch),
            endUtc: endUtc == null
                ? const Value.absent()
                : Value(endUtc.toUtc().millisecondsSinceEpoch),
            startDate: startDate == null
                ? const Value.absent()
                : Value(startDate),
            endDate: endDate == null ? const Value.absent() : Value(endDate),
            location: location == null ? const Value.absent() : Value(location),
            meetUrl: meetUrl == null ? const Value.absent() : Value(meetUrl),
            visibility: visibility == null
                ? const Value.absent()
                : Value(visibility),
            transparency: transparency == null
                ? const Value.absent()
                : Value(transparency),
            colorId: colorId == null ? const Value.absent() : Value(colorId),
            tzId: tzId == null ? const Value.absent() : Value(tzId),
            createMeet: createMeet == null
                ? const Value.absent()
                : Value(createMeet),
            reminders: reminders == null
                ? const Value.absent()
                : Value(reminders()),
            alarmPreset: alarmPreset == null
                ? const Value.absent()
                : Value(alarmPreset()),
            status: const Value('confirmed'),
            deletedAt: const Value(null),
            notes: notePatch,
          ),
        );
        await _enqueue(affectedId, 'update');
      case EditScope.following:
        affectedId = await _splitMaster(
          master,
          cutMs,
          title: title,
          startUtc: startUtc,
          endUtc: endUtc,
          location: location,
          rrule: rrule == null ? null : rrule(),
          startDate: startDate,
          endDate: endDate,
          notes: notePatch,
        );
        await _enqueue(masterId, 'update');
      case EditScope.all:
        await (_db.update(
          _db.events,
        )..where((e) => e.id.equals(masterId))).write(
          EventsCompanion(
            title: title == null ? const Value.absent() : Value(title),
            startUtc: startUtc == null
                ? const Value.absent()
                : Value(startUtc.toUtc().millisecondsSinceEpoch),
            endUtc: endUtc == null
                ? const Value.absent()
                : Value(endUtc.toUtc().millisecondsSinceEpoch),
            startDate: startDate == null
                ? const Value.absent()
                : Value(startDate),
            endDate: endDate == null ? const Value.absent() : Value(endDate),
            location: location == null ? const Value.absent() : Value(location),
            meetUrl: meetUrl == null ? const Value.absent() : Value(meetUrl),
            visibility: visibility == null
                ? const Value.absent()
                : Value(visibility),
            transparency: transparency == null
                ? const Value.absent()
                : Value(transparency),
            colorId: colorId == null ? const Value.absent() : Value(colorId),
            tzId: tzId == null ? const Value.absent() : Value(tzId),
            createMeet: createMeet == null
                ? const Value.absent()
                : Value(createMeet),
            rrule: rrule == null ? const Value.absent() : Value(rrule()),
            reminders: reminders == null
                ? const Value.absent()
                : Value(reminders()),
            alarmPreset: alarmPreset == null
                ? const Value.absent()
                : Value(alarmPreset()),
            notes: notePatch,
            updatedAt: Value(nowMs()),
            dirty: const Value(true),
          ),
        );
        if (resetExceptions) {
          final now = nowMs();
          for (final ex in await exceptionsOf(masterId)) {
            // The exception is about to disappear locally: drop any queued
            // create/update before deciding whether a remote delete is due.
            await (_db.delete(
              _db.outbox,
            )..where((o) => o.entityId.equals(ex.id))).go();
            if (ex.remoteId != null) {
              await _enqueue(ex.id, 'delete');
            }
            await (_db.update(
              _db.events,
            )..where((e) => e.id.equals(ex.id))).write(
              EventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
            );
          }
        }
        await _enqueue(masterId, 'update');
        affectedId = masterId;
    }
    await _occ.invalidateEvent(masterId);
    // Date edits keep a linked countdown in step; title/notes-only edits do not
    // reset a user-chosen countdown target date.
    if (syncLinkedDate && (startUtc != null || startDate != null)) {
      await syncLinkedCountdownDate(affectedId);
    }
    return affectedId;
  }
}
