// Event and calendar repository: CRUD, recurrence scope ops (PLAN 5.4),
// outbox rows, occurrence-cache invalidation.
// UI reads occurrences via OccurrenceRepository streams.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ephemeron/core/ids/ids.dart';
import 'package:ephemeron/core/search/sanitize.dart';
import 'package:ephemeron/core/time/time.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/outbox_helper.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/domain/sources/source_move.dart';

part 'event_repository/create.dart';
part 'event_repository/move.dart';
part 'event_repository/occurrence_ops.dart';
part 'event_repository/occurrence_exception_ops.dart';
part 'event_repository/occurrence_split_ops.dart';
part 'event_repository/calendars.dart';
part 'event_repository/device_import.dart';
part 'event_repository/helpers.dart';

enum EditScope { single, following, all }

const _readOnlyMessage = 'That calendar is read-only.';

class _EventRepositoryBase {
  _EventRepositoryBase(this._db, this._occ);

  final AppDatabase _db;
  final OccurrenceRepository _occ;

  Future<void> _enqueue(String entityId, String op, {String? payload}) =>
      enqueueOutbox(
        _db,
        entity: 'event',
        entityId: entityId,
        op: op,
        payload: payload,
      );

  Future<void> _enqueueRemoteDelete({
    required String eventId,
    required String calendarRemoteId,
    required String eventRemoteId,
    required String account,
  }) {
    return enqueueOutbox(
      _db,
      entity: 'event_remote',
      entityId: eventId,
      op: 'delete',
      payload: jsonEncode({
        'account': account,
        'calendarRemoteId': calendarRemoteId,
        'eventRemoteId': eventRemoteId,
      }),
    );
  }

  Future<String?> _accountOfCalendar(String calendarId) async {
    return (await _calendar(calendarId))?.googleAccount;
  }

  Future<Calendar?> _calendar(String calendarId) {
    return (_db.select(
      _db.calendars,
    )..where((c) => c.id.equals(calendarId))).getSingleOrNull();
  }

  /// True when [event]'s source calendar, or its recurring master's calendar,
  /// is read-only. Exceptions inherit the master's write protection.
  Future<bool> isEventReadOnly(Event event) async {
    if ((await _calendar(event.calendarId))?.readOnly == true) return true;
    final masterId = event.recurringMasterId;
    if (masterId == null) return false;
    final master = await (dbSelect()..where((e) => e.id.equals(masterId)))
        .getSingleOrNull();
    if (master == null) return false;
    return (await _calendar(master.calendarId))?.readOnly == true;
  }

  Future<void> _assertEventWritable(Event event) async {
    if (await isEventReadOnly(event)) {
      throw SourceMoveException(_readOnlyMessage);
    }
  }

  Future<Event> _master(String id) async {
    return (dbSelect()..where((e) => e.id.equals(id))).getSingle();
  }

  SimpleSelectStatement<$EventsTable, Event> dbSelect() =>
      _db.select(_db.events);

  Future<List<Event>> exceptionsOf(String masterId) {
    return (dbSelect()..where(
          (e) => e.recurringMasterId.equals(masterId) & e.deletedAt.isNull(),
        ))
        .get();
  }

  /// Soft-deletes a master and its exceptions in one transaction.
  Future<void> deleteEvent(String masterId) async {
    await _assertEventWritable(await _master(masterId));
    final now = nowMs();
    await _db.transaction(() async {
      for (final id in [
        masterId,
        for (final ex in await exceptionsOf(masterId)) ex.id,
      ]) {
        await (_db.update(_db.events)..where((e) => e.id.equals(id))).write(
          EventsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            dirty: const Value(true),
          ),
        );
      }
    });
    await _enqueue(masterId, 'delete');
    await _occ.invalidateEvent(masterId);
  }

  /// Next calendar day for a `YYYY-MM-DD` string.
  String _nextDate(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return date;
    return _dateOf(DateTime.utc(year, month, day + 1).millisecondsSinceEpoch);
  }

  int? _seriesFirstStart(Event master) => master.startUtc;

  String _stripCount(String rrule) {
    final parts = rrule
        .split(';')
        .where((p) => !p.toUpperCase().startsWith('COUNT='));
    return parts.join(';');
  }

  String _untilUtc(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    String p(int v, int w) => v.toString().padLeft(w, '0');
    return '${p(d.year, 4)}${p(d.month, 2)}${p(d.day, 2)}T${p(d.hour, 2)}${p(d.minute, 2)}${p(d.second, 2)}Z';
  }

  String _dateOf(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

class EventRepository extends _EventRepositoryBase
    with
        _EventCreateOps,
        _EventMoveOps,
        _EventOccurrenceExceptionOps,
        _EventOccurrenceSplitOps,
        _EventOccurrenceOps,
        _EventCalendarOps,
        _EventDeviceImportOps,
        _EventHelperOps {
  EventRepository(super._db, super._occ);

  Future<Event?> getEvent(String id) {
    return (dbSelect()..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  /// Loads [eventId] and resolves the occurrence exception selected at
  /// [occurrenceStartMs]. A recurring master falls back to itself when no live,
  /// non-cancelled exception matches originalStart or startUtc.
  Future<Event?> resolveEventForOccurrence(
    String eventId, {
    int? occurrenceStartMs,
  }) async {
    final event = await getEvent(eventId);
    if (event == null || occurrenceStartMs == null) return event;
    if (event.recurringMasterId != null) return event;
    final rrule = event.rrule;
    if (rrule == null || rrule.isEmpty) return event;
    final rows =
        await (dbSelect()..where(
              (e) =>
                  e.recurringMasterId.equals(event.id) &
                  e.deletedAt.isNull() &
                  e.status.isNotValue('cancelled') &
                  (e.originalStart.equals(occurrenceStartMs) |
                      e.startUtc.equals(occurrenceStartMs)),
            ))
            .get();
    if (rows.isEmpty) return event;
    return rows
            .where((e) => e.originalStart == occurrenceStartMs)
            .firstOrNull ??
        rows.first;
  }

  /// Pure self-resolution over already-loaded rows (see [selfAttendeeOf]).
  static EventAttendee? resolveSelf(
    List<EventAttendee> atts,
    List<String> accountEmails,
  ) => _EventCalendarOps.resolveSelf(atts, accountEmails);
}
