part of '../microsoft_sync_engine.dart';

/// Remote deletion reconciliation for Microsoft calendars and events.
///
/// Both reconcilers run only after a complete, successful listing. A failed or
/// partial fetch must never look like a remote deletion, so callers invoke these
/// only on the success path and per calendar.
extension on MicrosoftSyncEngine {
  /// Soft-deletes own-account Microsoft calendars that are absent from a
  /// complete `/me/calendars` listing.
  ///
  /// Local-only rows (no remote id), dirty rows, and rows stamped with another
  /// account are never touched. The latter are shared calendars whose lifecycle
  /// belongs to the account that owns them, so one account cannot delete
  /// another account's calendar row.
  Future<void> _reconcileDeletedCalendars(
    List<MsCalendar> calendars,
    int nowMs,
  ) async {
    final remoteIds = {
      for (final c in calendars)
        if (c.id.isNotEmpty) c.id,
    };
    final candidates =
        await (_db.select(_db.calendars)..where(
              (c) =>
                  c.source.equals('microsoft') &
                  c.remoteId.isNotNull() &
                  c.deletedAt.isNull() &
                  c.dirty.equals(false),
            ))
            .get();
    for (final calendar in candidates) {
      final remoteId = calendar.remoteId;
      if (remoteId == null || remoteId.isEmpty) continue;
      if (!_isOwnAccount(calendar.microsoftAccount)) continue;
      if (remoteIds.contains(remoteId)) continue;
      await (_db.update(
        _db.calendars,
      )..where((c) => c.id.equals(calendar.id))).write(
        CalendarsCompanion(
          deletedAt: Value(nowMs),
          updatedAt: Value(nowMs),
          dirty: const Value(false),
        ),
      );
    }
  }

  /// Soft-deletes clean Microsoft events in [localCalendarId] that overlap the
  /// fetched window but are absent from [remoteEventIds].
  ///
  /// Graph `calendarView` is time-windowed, so rows outside the window are left
  /// alone: their absence proves nothing. Rows without a provable overlap and
  /// recurring rows are skipped fail-safe (see [_overlapsFetchedWindow]).
  Future<void> _reconcileDeletedEvents(
    String localCalendarId,
    Set<String> remoteEventIds,
    int nowMs,
  ) async {
    final candidates =
        await (_db.select(_db.events)..where(
              (e) =>
                  e.calendarId.equals(localCalendarId) &
                  e.remoteId.isNotNull() &
                  e.deletedAt.isNull() &
                  e.dirty.equals(false),
            ))
            .get();
    for (final event in candidates) {
      final remoteId = event.remoteId;
      if (remoteId == null || remoteId.isEmpty) continue;
      if (remoteEventIds.contains(remoteId)) continue;
      if (!_overlapsFetchedWindow(event)) continue;
      await (_db.update(_db.events)..where((e) => e.id.equals(event.id))).write(
        EventsCompanion(
          // Preserve every local-only field; only the tombstone changes.
          deletedAt: Value(nowMs),
          updatedAt: Value(nowMs),
        ),
      );
    }
  }

  /// Whether [event] provably overlaps the window this engine fetched.
  ///
  /// Recurring rows are skipped: Microsoft occurrences are stored as single
  /// events and this engine never writes `rrule`/`recurringMasterId`, so a row
  /// carrying them has overlap semantics that a single expanded window cannot
  /// prove. Missing or inverted times are skipped for the same reason.
  bool _overlapsFetchedWindow(Event event) {
    if (event.rrule != null || event.recurringMasterId != null) return false;
    if (event.isAllDay) {
      final start = _utcDayStart(event.startDate);
      final end = _utcDayStart(event.endDate);
      if (start == null || end == null || !end.isAfter(start)) return false;
      // All-day end dates are exclusive, matching both Graph and the table.
      return start.isBefore(_windowEnd) && end.isAfter(_windowStart);
    }
    final startMs = event.startUtc;
    final endMs = event.endUtc;
    if (startMs == null || endMs == null || endMs <= startMs) return false;
    return startMs < _windowEnd.millisecondsSinceEpoch &&
        endMs > _windowStart.millisecondsSinceEpoch;
  }

  DateTime? _utcDayStart(String? value) {
    if (value == null || value.length != 10) return null;
    return DateTime.tryParse('${value}T00:00:00Z')?.toUtc();
  }
}
