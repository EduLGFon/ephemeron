part of '../event_repository.dart';

mixin _EventOccurrenceExceptionOps on _EventRepositoryBase {
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
}
