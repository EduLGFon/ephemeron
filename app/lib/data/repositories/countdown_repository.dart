// Countdowns. Local-first.
import 'package:drift/drift.dart';
import 'package:ephemeron/core/ids/ids.dart';
import 'package:ephemeron/core/search/sanitize.dart';
import 'package:ephemeron/core/time/time.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/pending_operations_repository.dart';

/// Local entities a countdown can be attached to.
const countdownLinkedTypes = {'event', 'task', 'habit'};

/// Unknown link types and empty ids degrade to an unlinked countdown.
({String? type, String? id}) normalizeCountdownLink(String? type, String? id) {
  final t = type?.trim();
  final i = id?.trim();
  if (t == null ||
      i == null ||
      i.isEmpty ||
      !countdownLinkedTypes.contains(t)) {
    return (type: null, id: null);
  }
  return (type: t, id: i);
}

class CountdownRepository {
  CountdownRepository(this._db);
  final AppDatabase _db;

  Future<String> createCountdown({
    required String title,
    String? targetDate,
    bool yearlyRepeat = false,
    bool showAge = false,
    String? notes,
    String? type,
    int? alertOffsetDays,
    int? alertTimeMin,
    String? alarmPreset,
    String? linkedType,
    String? linkedId,
  }) async {
    final id = newId();
    final now = nowMs();
    final link = normalizeCountdownLink(linkedType, linkedId);
    await _db
        .into(_db.countdowns)
        .insert(
          CountdownsCompanion.insert(
            id: id,
            title: title,
            type: Value(type),
            targetDate: Value(targetDate),
            yearlyRepeat: Value(yearlyRepeat),
            showAge: Value(showAge),
            notes: Value(notes),
            alertOffsetDays: Value(alertOffsetDays),
            alertTimeMin: Value(alertTimeMin),
            alarmPreset: Value(alarmPreset),
            linkedType: Value(link.type),
            linkedId: Value(link.id),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Stream<List<Countdown>> watchCountdowns() {
    final q = _db.select(_db.countdowns)
      ..where(
        (c) =>
            c.deletedAt.isNull() &
            c.id.isNotInQuery(
              pendingIdsQuery(_db, entity: 'countdown', ops: const {'delete'}),
            ),
      );
    q.orderBy([(c) => OrderingTerm.asc(c.targetDate)]);
    return q.watch();
  }

  /// Countdowns attached to one local entity, oldest target date first.
  Stream<List<Countdown>> watchLinkedCountdowns(String type, String id) {
    final link = normalizeCountdownLink(type, id);
    if (link.id == null) return Stream.value(const <Countdown>[]);
    final q = _db.select(_db.countdowns)
      ..where(
        (c) =>
            c.deletedAt.isNull() &
            c.linkedType.equals(link.type!) &
            c.linkedId.equals(link.id!) &
            c.id.isNotInQuery(
              pendingIdsQuery(_db, entity: 'countdown', ops: const {'delete'}),
            ),
      );
    q.orderBy([(c) => OrderingTerm.asc(c.targetDate)]);
    return q.watch();
  }

  /// Moves every live countdown linked to [type]/[id] to [targetDate].
  /// A null/empty date is a no-op: the entity has no natural date to follow.
  Future<void> syncLinkedTargetDate(
    String type,
    String id,
    String? targetDate,
  ) async {
    final link = normalizeCountdownLink(type, id);
    final date = targetDate?.trim();
    if (link.id == null || date == null || date.isEmpty) return;
    await (_db.update(_db.countdowns)..where(
          (c) =>
              c.linkedType.equals(link.type!) &
              c.linkedId.equals(link.id!) &
              c.deletedAt.isNull(),
        ))
        .write(
          CountdownsCompanion(
            targetDate: Value(date),
            updatedAt: Value(nowMs()),
          ),
        );
  }

  /// Removes the entity link without touching the countdown's content.
  Future<void> clearLink(String id) async {
    await (_db.update(_db.countdowns)..where((c) => c.id.equals(id))).write(
      CountdownsCompanion(
        linkedType: const Value(null),
        linkedId: const Value(null),
        updatedAt: Value(nowMs()),
      ),
    );
  }

  /// Global-search hits over live countdowns.
  Future<List<Countdown>> searchCountdowns(
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final stripped = sanitizeSearch(q);
    if (stripped.isEmpty) return [];
    final like = '%$stripped%';
    return (_db.select(_db.countdowns)
          ..where(
            (c) =>
                c.deletedAt.isNull() &
                c.id.isNotInQuery(
                  pendingIdsQuery(
                    _db,
                    entity: 'countdown',
                    ops: const {'delete'},
                  ),
                ) &
                c.title.like(like),
          )
          ..orderBy([(c) => OrderingTerm.asc(c.targetDate)])
          ..limit(limit))
        .get();
  }

  Future<void> updateCountdown(
    String id, {
    String? title,
    String? Function()? targetDate,
    bool? yearlyRepeat,
    bool? showAge,
    String? Function()? notes,
    int? Function()? alertOffsetDays,
    int? Function()? alertTimeMin,
    String? Function()? alarmPreset,
    String? Function()? linkedType,
    String? Function()? linkedId,
  }) async {
    // Passing either link closure rewrites the pair; absent closures keep the
    // existing link. The editor passes both so Unlink writes null/null.
    final linkChanged = linkedType != null || linkedId != null;
    final link = linkChanged
        ? normalizeCountdownLink(linkedType?.call(), linkedId?.call())
        : null;
    await (_db.update(_db.countdowns)..where((c) => c.id.equals(id))).write(
      CountdownsCompanion(
        title: title == null ? const Value.absent() : Value(title),
        targetDate: targetDate == null
            ? const Value.absent()
            : Value(targetDate()),
        yearlyRepeat: yearlyRepeat == null
            ? const Value.absent()
            : Value(yearlyRepeat),
        showAge: showAge == null ? const Value.absent() : Value(showAge),
        notes: notes == null ? const Value.absent() : Value(notes()),
        alertOffsetDays: alertOffsetDays == null
            ? const Value.absent()
            : Value(alertOffsetDays()),
        alertTimeMin: alertTimeMin == null
            ? const Value.absent()
            : Value(alertTimeMin()),
        alarmPreset: alarmPreset == null
            ? const Value.absent()
            : Value(alarmPreset()),
        linkedType: link == null ? const Value.absent() : Value(link.type),
        linkedId: link == null ? const Value.absent() : Value(link.id),
        updatedAt: Value(nowMs()),
      ),
    );
  }

  Future<void> restoreCountdown(String id) async {
    await (_db.update(_db.countdowns)..where((c) => c.id.equals(id))).write(
      CountdownsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(nowMs()),
      ),
    );
  }

  Future<void> deleteCountdown(String id) async {
    await (_db.update(_db.countdowns)..where((c) => c.id.equals(id))).write(
      CountdownsCompanion(deletedAt: Value(nowMs()), updatedAt: Value(nowMs())),
    );
  }
}
