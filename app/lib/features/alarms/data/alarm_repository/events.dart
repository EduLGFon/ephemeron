part of '../alarm_repository.dart';

mixin _AlarmEventCandidatesOps on _AlarmRepositoryBase {
  Future<List<AlarmCandidate>> _eventCandidates(int now) async {
    final occs =
        await (_db.select(_db.occurrenceCache)
              ..where(
                (c) =>
                    c.startUtc.isBiggerThanValue(now - msPerDay) &
                    c.sourceType.equals('event'),
              )
              ..orderBy([(c) => OrderingTerm.asc(c.startUtc)])
              ..limit(500))
            .get();
    if (occs.isEmpty) return [];
    final eventIds = {for (final o in occs) o.eventId};
    final events = await (_db.select(
      _db.events,
    )..where((e) => e.id.isIn(eventIds.toList()))).get();
    final byId = {for (final e in events) e.id: e};
    // All-day overrides are cached under the exception id, so load their
    // masters too when they are not part of the occurrence key set.
    final masterIds = <String>{
      for (final e in events)
        if (e.recurringMasterId != null) e.recurringMasterId!,
    };
    final missingMasterIds = masterIds
        .where((id) => !byId.containsKey(id))
        .toList();
    if (missingMasterIds.isNotEmpty) {
      final masters = await (_db.select(
        _db.events,
      )..where((e) => e.id.isIn(missingMasterIds))).get();
      for (final master in masters) {
        byId[master.id] = master;
      }
    }
    // Timed recurring cache rows point at the master. Load their exceptions
    // once so an occurrence can use its own reminders/alarm when present.
    final recurringMasterIds = <String>{
      for (final e in events)
        if (e.recurringMasterId == null &&
            e.rrule != null &&
            e.rrule!.isNotEmpty)
          e.id,
    };
    final exceptionsByMaster = <String, List<Event>>{};
    if (recurringMasterIds.isNotEmpty) {
      final exceptions =
          await (_db.select(_db.events)..where(
                (e) =>
                    e.recurringMasterId.isIn(recurringMasterIds.toList()) &
                    e.deletedAt.isNull(),
              ))
              .get();
      for (final ex in exceptions) {
        final masterId = ex.recurringMasterId;
        if (masterId == null) continue;
        exceptionsByMaster.putIfAbsent(masterId, () => []).add(ex);
      }
    }
    final out = <AlarmCandidate>[];
    final seen = <String>{};
    for (final o in occs) {
      final e = byId[o.eventId];
      if (e == null || e.deletedAt != null) continue;
      final key = '${e.id}@${o.startUtc}';
      if (!seen.add(key)) continue;
      Event? master;
      Event? exception;
      if (e.recurringMasterId != null) {
        exception = e;
        master = byId[e.recurringMasterId!];
      } else if (e.rrule != null && e.rrule!.isNotEmpty) {
        master = e;
        for (final ex in exceptionsByMaster[e.id] ?? const <Event>[]) {
          if (ex.originalStart == o.startUtc || ex.startUtc == o.startUtc) {
            exception = ex;
            break;
          }
        }
      }
      // An exception owns its alerts only when it stored them; otherwise it
      // inherits the master. The fire time is always this occurrence's slot.
      final reminders =
          exception?.reminders ?? master?.reminders ?? e.reminders;
      final alarmPreset =
          exception?.alarmPreset ?? master?.alarmPreset ?? e.alarmPreset;
      final title = exception?.title ?? e.title;
      final resolvedTitle = title.isEmpty ? 'Event' : title;
      final offsets = parseReminderOffsets(reminders, allDay: e.isAllDay);
      final base = e.isAllDay ? _nineAmForDay(o.dayKey) : o.startUtc;
      for (final off in offsets) {
        out.add(
          AlarmCandidate(
            sourceType: 'event_reminder',
            sourceId: '$key#r$off',
            fireAtUtcMs: base - off * msPerMinute,
            preset: AlarmPreset.notification.id,
            kind: 'reminder',
            title: resolvedTitle,
            allDay: e.isAllDay,
          ),
        );
      }
      final preset = parseAlarmPreset(alarmPreset);
      if (preset != null) {
        out.add(
          AlarmCandidate(
            sourceType: 'event',
            sourceId: key,
            fireAtUtcMs: base,
            preset: preset.id,
            kind: 'alarm',
            title: resolvedTitle,
            allDay: e.isAllDay,
          ),
        );
      }
    }
    return out;
  }
}
