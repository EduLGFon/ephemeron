part of '../habit_repository.dart';

mixin _HabitLogOps on _HabitRepositoryBase {
  Stream<List<HabitLog>> watchLogs(String habitId) {
    final q = _db.select(_db.habitLogs)
      ..where((l) => l.habitId.equals(habitId))
      ..orderBy([(l) => OrderingTerm.asc(l.dayKey)]);
    return q.watch();
  }

  Future<HabitLog?> logFor(String habitId, String dayKey) {
    return (_db.select(_db.habitLogs)
          ..where((l) => l.habitId.equals(habitId) & l.dayKey.equals(dayKey)))
        .getSingleOrNull();
  }

  Future<double> _habitGoal(String habitId) async {
    final habit = await (_db.select(
      _db.habits,
    )..where((h) => h.id.equals(habitId))).getSingleOrNull();
    return habit?.goalAmount ?? 0;
  }

  /// Done logs fill a positive goal without capping overfill.
  double _fillGoal(double amount, double goal) =>
      goal > 0 && amount < goal ? goal : amount;

  Future<void> logDone(String habitId, String dayKey, {double? amount}) async {
    final goal = await _habitGoal(habitId);
    final existing = await logFor(habitId, dayKey);
    final nextAmount = _fillGoal((existing?.amount ?? 0) + (amount ?? 0), goal);
    if (existing == null) {
      await _db
          .into(_db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              id: newId(),
              habitId: habitId,
              dayKey: dayKey,
              amount: Value(nextAmount),
              done: const Value(true),
              createdAt: nowMs(),
              updatedAt: nowMs(),
            ),
          );
    } else {
      await (_db.update(
        _db.habitLogs,
      )..where((l) => l.id.equals(existing.id))).write(
        HabitLogsCompanion(
          done: const Value(true),
          skipped: const Value(false),
          amount: Value(nextAmount),
          updatedAt: Value(nowMs()),
        ),
      );
    }
    await _enqueue('habit_log:$habitId', '$habitId@$dayKey', 'update');
    await _touchHabit(habitId);
    await cancelHabitDayAlarms(_db, habitId, dayKey);
  }

  /// Adds [amount] to the day's goal progress, creating the log if needed.
  /// Done and skipped are preserved; the log is marked done when a positive
  /// goal amount is reached.
  Future<void> addAmount(String habitId, String dayKey, double amount) async {
    final habit = await (_db.select(
      _db.habits,
    )..where((h) => h.id.equals(habitId))).getSingleOrNull();
    final goal = habit?.goalAmount ?? 0;
    final existing = await logFor(habitId, dayKey);
    final next = (existing?.amount ?? 0) + amount;
    final reachedDone = existing?.done == true || (goal > 0 && next >= goal);
    if (existing == null) {
      await _db
          .into(_db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              id: newId(),
              habitId: habitId,
              dayKey: dayKey,
              amount: Value(next),
              done: Value(reachedDone),
              createdAt: nowMs(),
              updatedAt: nowMs(),
            ),
          );
    } else {
      await (_db.update(
        _db.habitLogs,
      )..where((l) => l.id.equals(existing.id))).write(
        HabitLogsCompanion(
          amount: Value(next),
          done: Value(reachedDone),
          updatedAt: Value(nowMs()),
        ),
      );
    }
    await _enqueue('habit_log:$habitId', '$habitId@$dayKey', 'update');
    await _touchHabit(habitId);
    if (reachedDone) {
      await cancelHabitDayAlarms(_db, habitId, dayKey);
    }
  }

  Future<void> setSkipped(String habitId, String dayKey, bool skipped) async {
    final existing = await logFor(habitId, dayKey);
    if (existing == null) {
      await _db
          .into(_db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              id: newId(),
              habitId: habitId,
              dayKey: dayKey,
              skipped: Value(skipped),
              createdAt: nowMs(),
              updatedAt: nowMs(),
            ),
          );
    } else {
      await (_db.update(
        _db.habitLogs,
      )..where((l) => l.id.equals(existing.id))).write(
        HabitLogsCompanion(skipped: Value(skipped), updatedAt: Value(nowMs())),
      );
    }
    await _enqueue('habit_log:$habitId', '$habitId@$dayKey', 'update');
    await _touchHabit(habitId);
  }

  /// Marks the day done or not done. Unmarking resets the amount to 0 but
  /// preserves the skipped flag and does not cancel scheduled alarms.
  Future<void> setDone(String habitId, String dayKey, bool done) async {
    final existing = await logFor(habitId, dayKey);
    final nextAmount = done
        ? _fillGoal(existing?.amount ?? 0, await _habitGoal(habitId))
        : 0.0;
    if (existing == null) {
      await _db
          .into(_db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              id: newId(),
              habitId: habitId,
              dayKey: dayKey,
              amount: Value(nextAmount),
              done: Value(done),
              skipped: Value(false),
              createdAt: nowMs(),
              updatedAt: nowMs(),
            ),
          );
    } else {
      await (_db.update(
        _db.habitLogs,
      )..where((l) => l.id.equals(existing.id))).write(
        HabitLogsCompanion(
          done: Value(done),
          skipped: done ? const Value(false) : const Value.absent(),
          amount: Value(nextAmount),
          updatedAt: Value(nowMs()),
        ),
      );
    }
    await _enqueue('habit_log:$habitId', '$habitId@$dayKey', 'update');
    await _touchHabit(habitId);
    if (done) {
      await cancelHabitDayAlarms(_db, habitId, dayKey);
    }
  }

  /// Subtracts [amount] from the day's progress. Does nothing when no log
  /// exists so decrementing never creates a negative or zero row. A positive
  /// goal clears done when no longer reached and sets it when still reached;
  /// the skipped flag is preserved.
  Future<void> subtractAmount(
    String habitId,
    String dayKey,
    double amount,
  ) async {
    final existing = await logFor(habitId, dayKey);
    if (existing == null) return;
    final goal = await _habitGoal(habitId);
    final raw = existing.amount - amount;
    final next = raw < 0 ? 0.0 : raw;
    final reachedDone = goal > 0 ? next >= goal : existing.done;
    await (_db.update(
      _db.habitLogs,
    )..where((l) => l.id.equals(existing.id))).write(
      HabitLogsCompanion(
        amount: Value(next),
        done: Value(reachedDone),
        updatedAt: Value(nowMs()),
      ),
    );
    await _enqueue('habit_log:$habitId', '$habitId@$dayKey', 'update');
    await _touchHabit(habitId);
    if (reachedDone) {
      await cancelHabitDayAlarms(_db, habitId, dayKey);
    }
  }

  Future<void> toggleHabitDone(String habitId, String dayKey) async {
    final existing = await logFor(habitId, dayKey);
    if (existing != null && existing.done) {
      await setDone(habitId, dayKey, false);
    } else {
      await logDone(habitId, dayKey);
    }
  }

  Future<void> backfill(
    String habitId,
    String dayKey,
    double amount,
    bool done,
  ) async {
    final existing = await logFor(habitId, dayKey);
    if (existing == null) {
      await _db
          .into(_db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              id: newId(),
              habitId: habitId,
              dayKey: dayKey,
              amount: Value(amount),
              done: Value(done),
              createdAt: nowMs(),
              updatedAt: nowMs(),
            ),
          );
    } else {
      await (_db.update(
        _db.habitLogs,
      )..where((l) => l.id.equals(existing.id))).write(
        HabitLogsCompanion(
          amount: Value(amount),
          done: Value(done),
          updatedAt: Value(nowMs()),
        ),
      );
    }
    await _enqueue('habit_log:$habitId', '$habitId@$dayKey', 'update');
    await _touchHabit(habitId);
  }
}
