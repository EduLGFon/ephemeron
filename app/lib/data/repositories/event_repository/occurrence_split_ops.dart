part of '../event_repository.dart';

mixin _EventOccurrenceSplitOps
    on _EventRepositoryBase, _EventOccurrenceExceptionOps {
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
