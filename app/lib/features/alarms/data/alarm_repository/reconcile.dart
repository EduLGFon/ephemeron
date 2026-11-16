part of '../alarm_repository.dart';

mixin _AlarmReconcileOps on _AlarmRepositoryBase {
  /// Settles registrations whose moment passed while the app was asleep.
  ///
  /// Pending rows at or before [nowMs] become `missed` and their native
  /// registration is cancelled so they can never ring after the fact. Fired
  /// rows are only trusted while they are the active ring or the newest row
  /// delivered inside [firedGraceMs]; older ones are stale and become
  /// `missed`. Returns the number of settled rows.
  Future<int> reconcileOverdue({
    required int nowMs,
    int firedGraceMs = 2 * msPerMinute,
    int? activeRequestCode,
  }) async {
    final rows = await _db.select(_db.alarmsIndex).get();
    final overdue = rows
        .where(
          (r) =>
              (r.state == 'scheduled' || r.state == 'snoozed') &&
              r.fireAtUtc <= nowMs,
        )
        .toList();
    // Newest first, so the first row inside the grace window is the survivor.
    final fired = rows.where((r) => r.state == 'fired').toList()
      ..sort((a, b) => b.fireAtUtc.compareTo(a.fireAtUtc));
    final graceStartMs = nowMs - firedGraceMs;
    String? keepId;
    if (activeRequestCode != null) {
      for (final r in fired) {
        if (r.requestCode == activeRequestCode && r.fireAtUtc >= graceStartMs) {
          keepId = r.id;
          break;
        }
      }
    }
    if (keepId == null) {
      for (final r in fired) {
        if (r.fireAtUtc >= graceStartMs) {
          keepId = r.id;
          break;
        }
      }
    }
    final staleFired = fired.where((r) => r.id != keepId).toList();
    for (final row in [...overdue, ...staleFired]) {
      final code = row.requestCode;
      if (code != null) {
        // Cancel before writing the final state: native cancel also records
        // 'cancelled' in the shared alarms_index row.
        try {
          await AlarmScheduler.cancel(code);
        } catch (_) {}
      }
      await (_db.update(_db.alarmsIndex)..where((a) => a.id.equals(row.id)))
          .write(const AlarmsIndexCompanion(state: Value('missed')));
    }
    return overdue.length + staleFired.length;
  }
}
