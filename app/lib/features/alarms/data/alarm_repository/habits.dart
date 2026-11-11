part of '../alarm_repository.dart';

mixin _AlarmHabitCandidatesOps on _AlarmRepositoryBase {
  /// True while today's habit occurrence is still ringing. A rebuilt window
  /// must not schedule tomorrow's occurrence over an active alarm.
  Future<bool> _habitFiringToday(String habitId) async {
    final now = DateTime.now();
    final dayKey = habitDateKey(now);
    // Candidates store a legacy unpadded day key; accept both spellings so
    // the guard also works on single-digit days.
    final padded = '$habitId@$dayKey';
    final unpadded = '$habitId@${now.year}-${now.month}-${now.day}';
    final row =
        await (_db.select(_db.alarmsIndex)
              ..where(
                (a) =>
                    (a.sourceId.equals(padded) | a.sourceId.equals(unpadded)) &
                    a.state.equals('fired'),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<List<AlarmCandidate>> _habitCandidates(int now) async {
    final habits = await (_db.select(
      _db.habits,
    )..where((h) => h.archived.equals(false) & h.deletedAt.isNull())).get();
    final out = <AlarmCandidate>[];
    final localNow = DateTime.now();
    for (final h in habits) {
      if (h.reminderTime == null || h.reminderTime!.isEmpty) continue;
      final parts = h.reminderTime!.split(':');
      if (parts.length != 2) continue;
      final hh = int.tryParse(parts[0]);
      final mm = int.tryParse(parts[1]);
      if (hh == null || mm == null) continue;
      final preset = parseAlarmPreset(h.alarmPreset);
      final title = h.name.isEmpty ? 'Habit' : h.name;
      if (await _habitFiringToday(h.id)) continue;
      for (var dayOff = 0; dayOff < 14; dayOff++) {
        final day = localNow.add(Duration(days: dayOff));
        final local = DateTime(day.year, day.month, day.day, hh, mm);
        final fireMs = local.toUtc().millisecondsSinceEpoch;
        if (fireMs <= now) continue;
        if (dayOff == 0 && await _habitDoneToday(h.id)) continue;
        final sourceId = '${h.id}@${local.year}-${local.month}-${local.day}';
        if (preset == null || preset == AlarmPreset.notification) {
          out.add(
            AlarmCandidate(
              sourceType: 'habit_reminder',
              sourceId: sourceId,
              fireAtUtcMs: fireMs,
              preset: AlarmPreset.notification.id,
              kind: 'reminder',
              title: title,
              allDay: false,
            ),
          );
        } else {
          out.add(
            AlarmCandidate(
              sourceType: 'habit',
              sourceId: sourceId,
              fireAtUtcMs: fireMs,
              preset: preset.id,
              kind: 'alarm',
              title: title,
              allDay: false,
            ),
          );
        }
        break;
      }
    }
    return out;
  }
}
