part of '../event_repository.dart';

mixin _EventOccurrenceOps on _EventRepositoryBase {
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
    return affectedId;
  }

  Future<String> _upsertException(
    Event master,
    int originalStartMs,
    EventsCompanion changes,
  ) async {
    final existing =
        await (dbSelect()..where(
              (e) =>
                  e.recurringMasterId.equals(master.id) &
                  e.originalStart.equals(originalStartMs) &
                  e.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final now = nowMs();
    if (existing == null) {
      final id = newId();
      await _db
          .into(_db.events)
          .insert(
            _inheritExceptionFields(changes, master).copyWith(
              id: Value(id),
              calendarId: Value(master.calendarId),
              googleAccount: Value(master.googleAccount),
              title: changes.title.present
                  ? changes.title
                  : Value(master.title),
              notes: changes.notes.present
                  ? changes.notes
                  : Value(master.notes),
              recurringMasterId: Value(master.id),
              originalStart: Value(originalStartMs),
              startUtc: changes.startUtc.present
                  ? changes.startUtc
                  : Value(originalStartMs),
              endUtc: changes.endUtc.present
                  ? changes.endUtc
                  : Value(
                      originalStartMs +
                          ((master.endUtc ?? originalStartMs) -
                              (master.startUtc ?? originalStartMs)),
                    ),
              startDate: changes.startDate.present
                  ? changes.startDate
                  : Value(master.startDate),
              endDate: changes.endDate.present
                  ? changes.endDate
                  : Value(master.endDate),
              status: changes.status.present
                  ? changes.status
                  : const Value('confirmed'),
              isAllDay: Value(master.isAllDay),
              tzId: changes.tzId.present ? changes.tzId : Value(master.tzId),
              dirty: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return id;
    } else {
      await _pruneStaleDescriptionLink(existing);
      await (_db.update(
        _db.events,
      )..where((e) => e.id.equals(existing.id))).write(
        _inheritExceptionFields(
          changes,
          master,
          existing: existing,
        ).copyWith(updatedAt: Value(now), dirty: const Value(true)),
      );
      return existing.id;
    }
  }

  /// Applies master defaults to exception fields that the edit did not
  /// override. Existing non-null overrides are preserved on update; missing
  /// values are filled from the master so a moved occurrence keeps its
  /// location, Meet link, visibility, transparency, reminders, and alarm.
  EventsCompanion _inheritExceptionFields(
    EventsCompanion changes,
    Event master, {
    Event? existing,
  }) {
    Value<String?> fallback(
      Value<String?> change,
      String? current,
      String? inherited,
    ) {
      if (change.present) return change;
      return current == null ? Value(inherited) : const Value.absent();
    }

    return changes.copyWith(
      location: fallback(changes.location, existing?.location, master.location),
      meetUrl: fallback(changes.meetUrl, existing?.meetUrl, master.meetUrl),
      visibility: fallback(
        changes.visibility,
        existing?.visibility,
        master.visibility,
      ),
      transparency: fallback(
        changes.transparency,
        existing?.transparency,
        master.transparency,
      ),
      colorId: fallback(changes.colorId, existing?.colorId, master.colorId),
      endTzId: fallback(changes.endTzId, existing?.endTzId, master.endTzId),
      reminders: fallback(
        changes.reminders,
        existing?.reminders,
        master.reminders,
      ),
      alarmPreset: fallback(
        changes.alarmPreset,
        existing?.alarmPreset,
        master.alarmPreset,
      ),
      createMeet: changes.createMeet.present
          ? changes.createMeet
          : existing == null
          ? Value(master.createMeet)
          : const Value.absent(),
    );
  }

  Future<void> _truncateMaster(Event master, int cutMs) async {
    final until = master.isAllDay
        ? _dateOf(cutMs - msPerDay)
        : _untilUtc(cutMs - 1000);
    final base = _stripCount(master.rrule ?? '');
    final rrule = base.isEmpty ? '' : '$base;UNTIL=$until';
    await (_db.update(_db.events)..where((e) => e.id.equals(master.id))).write(
      EventsCompanion(
        rrule: Value(rrule.isEmpty ? null : rrule),
        updatedAt: Value(nowMs()),
        dirty: const Value(true),
      ),
    );
    for (final ex in await exceptionsOf(master.id)) {
      if ((ex.originalStart ?? 0) >= cutMs) {
        await (_db.update(_db.events)..where((e) => e.id.equals(ex.id))).write(
          EventsCompanion(
            deletedAt: Value(nowMs()),
            updatedAt: Value(nowMs()),
            notesOverflowNoteId: const Value(null),
          ),
        );
      }
    }
  }

  /// Drops the old master's description link when the canonical note is gone,
  /// trashed, or already owned by another event. A valid link is kept so the
  /// pre-split series still shows its full description.
  Future<void> _pruneStaleDescriptionLink(Event event) async {
    final noteId = event.notesOverflowNoteId;
    if (noteId == null) return;
    final note = await (_db.select(
      _db.notes,
    )..where((n) => n.id.equals(noteId))).getSingleOrNull();
    final valid =
        note != null &&
        note.deletedAt == null &&
        (note.linkedEventId == null || note.linkedEventId == event.id);
    if (valid) return;
    await (_db.update(_db.events)..where((e) => e.id.equals(event.id))).write(
      const EventsCompanion(notesOverflowNoteId: Value(null)),
    );
  }

  Future<String> _splitMaster(
    Event master,
    int cutMs, {
    String? title,
    DateTime? startUtc,
    DateTime? endUtc,
    String? startDate,
    String? endDate,
    String? location,
    String? rrule,
    Value<String?> notes = const Value.absent(),
  }) async {
    await _pruneStaleDescriptionLink(master);
    await _truncateMaster(master, cutMs);
    final durationMs =
        (master.endUtc ?? master.startUtc ?? cutMs) -
        (master.startUtc ?? cutMs);
    final newStart = startUtc?.toUtc().millisecondsSinceEpoch ?? cutMs;
    final newEnd =
        endUtc?.toUtc().millisecondsSinceEpoch ?? (newStart + durationMs);
    final id = newId();
    final now = nowMs();
    await _db
        .into(_db.events)
        .insert(
          EventsCompanion.insert(
            id: id,
            calendarId: master.calendarId,
            title: Value(title ?? master.title),
            startUtc: Value(newStart),
            endUtc: Value(newEnd),
            startDate: Value(startDate ?? master.startDate),
            endDate: Value(endDate ?? master.endDate),
            isAllDay: Value(master.isAllDay),
            tzId: Value(master.tzId),
            endTzId: Value(master.endTzId),
            rrule: Value(rrule ?? _stripCount(master.rrule ?? '')),
            location: Value(location ?? master.location),
            meetUrl: Value(master.meetUrl),
            visibility: Value(master.visibility),
            transparency: Value(master.transparency),
            colorId: Value(master.colorId),
            createMeet: Value(master.createMeet),
            reminders: Value(master.reminders),
            alarmPreset: Value(master.alarmPreset),
            notes: notes.present ? notes : Value(master.notes),
            // The split master starts with copied text but never a shared
            // canonical note: the first description save creates its own.
            notesOverflowNoteId: const Value(null),
            dirty: const Value(true),
            googleAccount: Value(master.googleAccount),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _enqueue(id, 'create');
    return id;
  }
}
