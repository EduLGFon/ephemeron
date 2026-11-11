part of '../alarm_repository.dart';

mixin _AlarmRebuildOps
    on
        _AlarmRepositoryBase,
        _AlarmEventCandidatesOps,
        _AlarmTaskCandidatesOps,
        _AlarmCountdownCandidatesOps,
        _AlarmHabitCandidatesOps {
  /// Rebuilds the rolling window: next 48 h plus next 60 future alarms.
  /// Called on app open, after occurrence rebuilds, and by the daily job.
  Future<int> rebuildWindow({bool dueTomorrowEnabled = true}) async {
    final now = _now();
    final candidates = <AlarmCandidate>[
      ...await _eventCandidates(now),
      ...await _taskCandidates(),
      if (dueTomorrowEnabled) ...await _dueTomorrowCandidates(now),
      ...await _countdownCandidates(now),
      ...await _habitCandidates(now),
    ];
    final existing = await _db.select(_db.alarmsIndex).get();
    // Keep fired rows alive while they may still be ringing, and snoozed rows
    // until they fire or are resolved, so the rebuild neither cancels their
    // native registrations nor reuses their request codes.
    final preserved = existing
        .where(
          (r) =>
              (r.state == 'fired' || r.state == 'snoozed') &&
              r.requestCode != null &&
              r.fireAtUtc >= now - 24 * msPerHour,
        )
        .toList();
    final preservedIds = {for (final r in preserved) r.id};
    final preservedCodes = {for (final r in preserved) r.requestCode!};
    final planned = planAlarmWindow(
      candidates,
      nowUtcMs: now,
      reservedRequestCodes: preservedCodes,
    );
    final existingCodes = {
      for (final r in existing)
        if (r.requestCode != null) r.requestCode!,
    };
    final plannedCodes = {for (final p in planned) p.requestCode};
    await _db.transaction(() async {
      if (preserved.isEmpty) {
        await _db.delete(_db.alarmsIndex).go();
      } else {
        await (_db.delete(
          _db.alarmsIndex,
        )..where((a) => a.id.isNotIn(preservedIds))).go();
      }
      for (final p in planned) {
        final base = p.title.isEmpty ? p.sourceId : p.title;
        final decorated = (p.sourceType == 'task_due_tomorrow')
            ? (p.allDay
                  ? base
                  : decorateAlarmTitle(
                      base,
                      p.fireAtUtcMs,
                      nowUtcMs: now,
                      allDay: false,
                      includeDayLabel: false,
                    ))
            : decorateAlarmTitle(
                base,
                p.fireAtUtcMs,
                nowUtcMs: now,
                allDay: p.allDay,
              );
        await _db
            .into(_db.alarmsIndex)
            .insert(
              AlarmsIndexCompanion.insert(
                id: newId(),
                sourceType: p.sourceType,
                sourceId: p.sourceId,
                fireAtUtc: p.fireAtUtcMs,
                presetStep: const Value(null),
                requestCode: Value(p.requestCode),
                state: const Value('scheduled'),
                kind: Value(p.kind),
                title: Value(decorated),
                preset: Value(p.preset),
              ),
            );
        final preset = AlarmPreset.tryParse(p.preset);
        if (p.kind == 'reminder') {
          await AlarmScheduler.scheduleReminder(
            requestCode: p.requestCode,
            fireAtUtcMs: p.fireAtUtcMs,
            title: decorated,
            sourceType: p.sourceType,
            sourceId: p.sourceId,
          );
        } else if (preset != null) {
          await AlarmScheduler.schedulePreset(
            requestCode: p.requestCode,
            fireAtUtcMs: p.fireAtUtcMs,
            preset: preset,
            title: decorated,
            sourceType: p.sourceType,
            sourceId: p.sourceId,
          );
        }
      }
    });
    for (final code
        in existingCodes.difference(preservedCodes).difference(plannedCodes)) {
      await AlarmScheduler.cancel(code);
    }
    return planned.length;
  }
}
