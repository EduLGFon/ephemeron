part of '../habit_repository.dart';

mixin _HabitStatsOps on _HabitRepositoryBase {
  HabitSpec specOf(Habit h);
  Future<HabitLog?> logFor(String habitId, String dayKey);

  Future<({int current, int best})> streaks(
    String habitId,
    String todayKey,
  ) async {
    final habit = await (_db.select(
      _db.habits,
    )..where((h) => h.id.equals(habitId))).getSingleOrNull();
    if (habit == null) return (current: 0, best: 0);
    final logs = await (_db.select(
      _db.habitLogs,
    )..where((l) => l.habitId.equals(habitId))).get();
    final spec = specOf(habit);
    bool isDone(String day) {
      for (final l in logs) {
        if (l.dayKey != day) continue;
        if (l.done) return true;
        if ((habit.goalAmount ?? 0) > 0 && l.amount >= habit.goalAmount!) {
          return true;
        }
      }
      return false;
    }

    bool isSkipped(String day) {
      for (final l in logs) {
        if (l.dayKey == day && l.skipped) return true;
      }
      return false;
    }

    return (
      current: currentStreak(spec, todayKey, isDone, isSkipped),
      best: bestStreak(spec, todayKey, isDone, isSkipped),
    );
  }

  Future<double> weeklyRate(String habitId, String todayKey) async {
    final today = parseKey(todayKey);
    var done = 0, total = 0;
    for (var i = 0; i < 7; i++) {
      final key = habitDateKey(today.subtract(Duration(days: i)));
      final log = await logFor(habitId, key);
      if (log == null) continue;
      total++;
      if (log.done) done++;
    }
    if (total == 0) return 0;
    return done / total;
  }

  Stream<HabitStatsSummary?> watchHabitStats(String habitId, String todayKey) {
    final q = _db.select(_db.habits).join([
      leftOuterJoin(
        _db.habitLogs,
        _db.habitLogs.habitId.equalsExp(_db.habits.id),
      ),
    ])..where(_db.habits.id.equals(habitId) & _db.habits.deletedAt.isNull());
    return q.watch().map((rows) {
      if (rows.isEmpty) return null;
      final habit = rows.first.readTable(_db.habits);
      final spec = specOf(habit);
      final logs = rows
          .map((r) => r.readTableOrNull(_db.habitLogs))
          .whereType<HabitLog>()
          .map(
            (l) => HabitLogEntry(
              dayKey: l.dayKey,
              amount: l.amount,
              done: l.done,
              skipped: l.skipped,
            ),
          )
          .toList();
      return computeHabitStats(
        todayKey: todayKey,
        spec: spec,
        unit: habit.unit,
        goalAmount: habit.goalAmount,
        logs: logs,
      );
    });
  }
}
