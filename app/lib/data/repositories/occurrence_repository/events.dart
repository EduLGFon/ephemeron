part of '../occurrence_repository.dart';

// Materializes event rows (recurring masters, all-day masters, singles)
// into `occurrence_cache` companions.
mixin _EventCacheOps on _OccurrenceRepositoryBase {
  void _collectMaster(
    List<OccurrenceCacheCompanion> rows,
    Event master,
    List<Event> exceptions,
    DateTime rangeStart,
    DateTime rangeEnd,
    Map<String, String?> calColors,
  ) {
    if (master.isAllDay) {
      _collectAllDayMaster(
        rows,
        master,
        exceptions,
        rangeStart,
        rangeEnd,
        calColors,
      );
      return;
    }
    if (master.startUtc == null) return;
    final durationMs = (master.endUtc ?? master.startUtc!) - master.startUtc!;
    final cancelled = <int>{
      for (final ex in exceptions)
        if (ex.status == 'cancelled' && ex.originalStart != null)
          ex.originalStart!,
    };
    final overrides = <int, Event>{
      for (final ex in exceptions)
        if (ex.status != 'cancelled' && ex.originalStart != null)
          ex.originalStart!: ex,
    };
    // Suppress original slots for moved (non-same-time) overrides.
    final exdate = <int>{...cancelled};
    for (final entry in overrides.entries) {
      final ex = entry.value;
      if (ex.startUtc != null && ex.startUtc != entry.key) {
        exdate.add(entry.key);
      }
    }
    final color = effectiveEventColor(
      eventColorId: master.colorId,
      calendarColor: calColors[master.calendarId],
      calendarId: master.calendarId,
    );
    final starts = expandOccurrences(
      startUtc: DateTime.fromMillisecondsSinceEpoch(
        master.startUtc!,
        isUtc: true,
      ),
      rrule: master.rrule!,
      tzId: master.tzId,
      rangeStartUtc: rangeStart,
      rangeEndUtc: rangeEnd,
      exdateUtcMs: exdate,
      cap: OccurrenceRepository.instanceCap,
    );
    for (final s in starts) {
      final key = s.millisecondsSinceEpoch;
      final override = overrides[key];
      final startMs = override?.startUtc ?? key;
      final endMs = override?.endUtc ?? (key + durationMs);
      rows.add(
        _row(
          master.id,
          startMs,
          endMs,
          _dayKey(startMs, master.tzId),
          title: override?.title ?? master.title,
          colorId: override?.colorId != null
              ? effectiveEventColor(
                  eventColorId: override!.colorId,
                  calendarColor: calColors[master.calendarId],
                  calendarId: master.calendarId,
                )
              : color,
        ),
      );
    }
    // Apply moved/edited overrides that landed on a different slot: emit
    // their own span (already handled above when key matches master slot).
    // Non-slot overrides (moved to a date the master did not originally
    // cover) are emitted here, but only when they overlap the rebuild window.
    final fromMs = rangeStart.toUtc().millisecondsSinceEpoch;
    final toMs = rangeEnd.toUtc().millisecondsSinceEpoch;
    final startKeys = <int>{for (final s in starts) s.millisecondsSinceEpoch};
    final emittedKeys = <String>{
      for (final r in rows)
        '${r.eventId.value}|${r.startUtc.value}|${r.dayKey.value}',
    };
    for (final entry in overrides.entries) {
      final originalKey = entry.key;
      if (startKeys.contains(originalKey)) {
        continue;
      }
      final ex = entry.value;
      if (ex.startUtc == null) continue;
      final exEnd = ex.endUtc ?? ex.startUtc!;
      if (exEnd < fromMs || ex.startUtc! > toMs) {
        continue;
      }
      // Avoid duplicate (eventId, startUtc, dayKey) rows.
      final dedupeKey =
          '${master.id}|${ex.startUtc}|${_dayKey(ex.startUtc!, master.tzId)}';
      if (emittedKeys.contains(dedupeKey)) {
        continue;
      }
      emittedKeys.add(dedupeKey);
      rows.add(
        _row(
          master.id,
          ex.startUtc!,
          exEnd,
          _dayKey(ex.startUtc!, master.tzId),
          title: ex.title,
          colorId: ex.colorId != null
              ? effectiveEventColor(
                  eventColorId: ex.colorId,
                  calendarColor: calColors[master.calendarId],
                  calendarId: master.calendarId,
                )
              : color,
        ),
      );
    }
  }

  void _collectAllDayMaster(
    List<OccurrenceCacheCompanion> rows,
    Event master,
    List<Event> exceptions,
    DateTime rangeStart,
    DateTime rangeEnd,
    Map<String, String?> calColors,
  ) {
    if (master.startDate == null) return;
    final cancelledKeys = <String>{
      for (final ex in exceptions)
        if (ex.status == 'cancelled' && ex.originalStart != null)
          dateKey(
            DateTime.fromMillisecondsSinceEpoch(ex.originalStart!, isUtc: true),
          ),
    };
    final overrides = <String, Event>{
      for (final ex in exceptions)
        if (ex.status != 'cancelled' && ex.originalStart != null)
          dateKey(
            DateTime.fromMillisecondsSinceEpoch(ex.originalStart!, isUtc: true),
          ): ex,
    };
    // Suppress original slots for moved/edited overrides.
    final exdateKeys = <String>{...cancelledKeys, ...overrides.keys};
    final parts = master.startDate!.split('-');
    var cursor = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final endParts = (master.endDate ?? master.startDate)!.split('-');
    final spanDaysRaw = DateTime.utc(
      int.parse(endParts[0]),
      int.parse(endParts[1]),
      int.parse(endParts[2]),
    ).difference(cursor).inDays;
    final spanDays = spanDaysRaw < 1 ? 1 : spanDaysRaw;
    final color = effectiveEventColor(
      eventColorId: master.colorId,
      calendarColor: calColors[master.calendarId],
      calendarId: master.calendarId,
    );
    final startKeyPad = dateKey(
      rangeStart.toUtc().subtract(const Duration(days: 1)),
    );
    final endKeyPad = dateKey(rangeEnd.toUtc().add(const Duration(days: 1)));
    final starts = expandOccurrences(
      startUtc: cursor,
      rrule: master.rrule!,
      allDay: true,
      rangeStartUtc: rangeStart,
      rangeEndUtc: rangeEnd,
      exdateDateKeys: exdateKeys,
      cap: OccurrenceRepository.instanceCap,
    );
    for (final s in starts) {
      final day = dateKey(s);
      if (day.compareTo(startKeyPad) < 0 || day.compareTo(endKeyPad) > 0) {
        continue;
      }
      final dayEnd = DateTime.utc(
        s.year,
        s.month,
        s.day,
      ).add(Duration(days: spanDays));
      rows.add(
        _row(
          master.id,
          s.millisecondsSinceEpoch,
          dayEnd.millisecondsSinceEpoch - 1,
          day,
          title: master.title,
          colorId: color,
        ),
      );
    }
    // Emit override spans (moved/edited all-day instances).
    for (final ex in overrides.values) {
      final oStartRaw = ex.startDate;
      if (oStartRaw == null) continue;
      final oParts = oStartRaw.split('-');
      var oCursor = DateTime.utc(
        int.parse(oParts[0]),
        int.parse(oParts[1]),
        int.parse(oParts[2]),
      );
      final oEndRaw = ex.endDate ?? ex.startDate!;
      final oEndParts = oEndRaw.split('-');
      final oEndBase = DateTime.utc(
        int.parse(oEndParts[0]),
        int.parse(oEndParts[1]),
        int.parse(oEndParts[2]),
      );
      final oSpanRaw = oEndBase.difference(oCursor).inDays;
      final oSpan = oSpanRaw < 1 ? 1 : oSpanRaw;
      final exColor = effectiveEventColor(
        eventColorId: ex.colorId,
        calendarColor: calColors[master.calendarId],
        calendarId: master.calendarId,
      );
      var oc = oCursor;
      final oEndExclusive = oCursor.add(Duration(days: oSpan));
      while (oc.isBefore(oEndExclusive)) {
        final dk = dateKey(oc);
        if (dk.compareTo(startKeyPad) >= 0 && dk.compareTo(endKeyPad) <= 0) {
          final next = oc.add(const Duration(days: 1));
          rows.add(
            _row(
              ex.id,
              oc.millisecondsSinceEpoch,
              next.millisecondsSinceEpoch - 1,
              dk,
              title: ex.title,
              colorId: exColor,
            ),
          );
        }
        oc = oc.add(const Duration(days: 1));
      }
    }
  }

  void _collectSingle(
    List<OccurrenceCacheCompanion> rows,
    Event e,
    DateTime rangeStart,
    DateTime rangeEnd,
    Map<String, String?> calColors,
  ) {
    final color = effectiveEventColor(
      eventColorId: e.colorId,
      calendarColor: calColors[e.calendarId],
      calendarId: e.calendarId,
    );
    if (e.isAllDay) {
      if (e.startDate == null) return;
      final lastRaw = e.endDate ?? e.startDate!;
      var cursor = _parseDate(e.startDate!);
      var end = _parseDate(lastRaw);
      if (!end.isAfter(cursor)) {
        end = cursor.add(const Duration(days: 1));
      }
      final startKey = dateKey(rangeStart);
      final endKey = dateKey(rangeEnd);
      if (e.startDate!.compareTo(endKey) > 0) return;
      if (dateKey(end).compareTo(startKey) <= 0) return;
      // Clamp iteration to the rebuild window (one-day padding handled by caller range).
      final windowStartDay = _parseDate(startKey);
      final windowEndDay = _parseDate(endKey).add(const Duration(days: 1));
      if (cursor.isBefore(windowStartDay)) cursor = windowStartDay;
      if (end.isAfter(windowEndDay)) end = windowEndDay;
      if (!cursor.isBefore(end)) return;
      var n = 0;
      while (cursor.isBefore(end)) {
        final next = cursor.add(const Duration(days: 1));
        rows.add(
          _row(
            e.id,
            cursor.millisecondsSinceEpoch,
            next.millisecondsSinceEpoch - 1,
            dateKey(cursor),
            title: e.title,
            colorId: color,
          ),
        );
        n++;
        if (n > 366) break;
        cursor = next;
      }
      return;
    }
    if (e.startUtc == null) return;
    final endMs = e.endUtc ?? e.startUtc!;
    if (endMs < rangeStart.toUtc().millisecondsSinceEpoch ||
        e.startUtc! > rangeEnd.toUtc().millisecondsSinceEpoch) {
      return;
    }
    rows.add(
      _row(
        e.id,
        e.startUtc!,
        endMs,
        _dayKey(e.startUtc!, e.tzId),
        title: e.title,
        colorId: color,
      ),
    );
  }
}
