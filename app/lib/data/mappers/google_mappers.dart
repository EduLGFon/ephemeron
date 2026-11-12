// Google Calendar/Tasks <-> Drift mappers. Local-only fields are never
// overwritten by remote data; last-writer-wins applies to shared fields.
import 'package:drift/drift.dart';

import '../../core/time/time.dart';
import '../../data/drift/app_database.dart';

class MappedEvent {
  MappedEvent({required this.companion, required this.remoteEtag});
  final EventsCompanion companion;
  final String? remoteEtag;
}

MappedEvent eventFromGoogle(
  Map<String, dynamic> g,
  String calendarId,
  String localId, {
  String? recurringMasterLocalId,
}) {
  final start = g['start'] as Map? ?? {};
  final end = g['end'] as Map? ?? {};
  final isAllDay = start['date'] != null;
  int? startUtc;
  int? endUtc;
  String? startDate;
  String? endDate;
  if (isAllDay) {
    // Google all-day end.date is EXCLUSIVE; store it unchanged.
    startDate = start['date'] as String?;
    endDate = end['date'] as String?;
  } else {
    final s = start['dateTime'] as String?;
    final e = end['dateTime'] as String?;
    if (s != null) {
      startUtc = DateTime.parse(s).toUtc().millisecondsSinceEpoch;
    }
    if (e != null) {
      endUtc = DateTime.parse(e).toUtc().millisecondsSinceEpoch;
    }
  }
  String? notes = g['description'] as String?;
  if (notes != null && notes.length > 8000) {
    // Remainder stays local-only until notes overflow lands (Phase 7).
    notes = notes.substring(0, 8000);
  }
  String? rrule;
  final rec = g['recurrence'] as List?;
  if (rec != null) {
    // Google may list EXDATE/RDATE lines before the RRULE; take the first
    // RRULE line instead of blindly reading the first element.
    for (final line in rec) {
      if (line is String && line.startsWith('RRULE:')) {
        rrule = line.substring('RRULE:'.length);
        break;
      }
    }
  }
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  int? originalStart;
  final ost = g['originalStartTime'];
  if (ost is Map) {
    final dt = ost['dateTime'];
    if (dt is String) {
      final parsed = DateTime.tryParse(dt);
      if (parsed != null) {
        originalStart = parsed.toUtc().millisecondsSinceEpoch;
      }
    } else {
      final d = ost['date'];
      if (d is String) {
        final p = d.split('-');
        if (p.length == 3) {
          final y = int.tryParse(p[0]);
          final m = int.tryParse(p[1]);
          final day = int.tryParse(p[2]);
          if (y != null &&
              m != null &&
              day != null &&
              m >= 1 &&
              m <= 12 &&
              day >= 1 &&
              day <= 31) {
            final dt = DateTime.utc(y, m, day);
            if (dt.year == y && dt.month == m && dt.day == day) {
              originalStart = dt.millisecondsSinceEpoch;
            }
          }
        }
      }
    }
  }
  return MappedEvent(
    companion: EventsCompanion(
      id: Value(localId),
      calendarId: Value(calendarId),
      title: Value((g['summary'] as String?) ?? ''),
      notes: Value(notes),
      location: Value(g['location'] as String?),
      startUtc: Value(startUtc),
      endUtc: Value(endUtc),
      startDate: Value(startDate),
      endDate: Value(endDate),
      isAllDay: Value(isAllDay),
      tzId: Value(start['timeZone'] as String?),
      endTzId: Value(end['timeZone'] as String?),
      rrule: Value(rrule),
      recurringMasterId: Value(recurringMasterLocalId),
      originalStart: Value(originalStart),
      status: Value((g['status'] as String?) ?? 'confirmed'),
      transparency: Value(g['transparency'] as String?),
      visibility: Value(g['visibility'] as String?),
      colorId: Value(g['colorId'] as String?),
      remoteId: Value(g['id'] as String?),
      remoteEtag: Value(g['etag'] as String?),
      dirty: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    remoteEtag: g['etag'] as String?,
  );
}

Map<String, dynamic> eventToGoogle(Event e) {
  final body = <String, dynamic>{
    'summary': e.title,
    if (e.notes != null) 'description': e.notes,
    if (e.location != null) 'location': e.location,
    'status': e.status,
    if (e.transparency != null) 'transparency': e.transparency,
    if (e.isAllDay)
      'start': {'date': e.startDate}
    else
      'start': {
        'dateTime': e.startUtc == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                e.startUtc!,
                isUtc: true,
              ).toIso8601String(),
        if (e.tzId != null) 'timeZone': e.tzId,
      },
    if (e.isAllDay)
      'end': {'date': _exclusiveAllDayEnd(e)}
    else
      'end': {
        'dateTime': e.endUtc == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                e.endUtc!,
                isUtc: true,
              ).toIso8601String(),
        if ((e.endTzId ?? e.tzId) != null) 'timeZone': e.endTzId ?? e.tzId,
      },
    if (e.colorId != null) 'colorId': e.colorId,
    if (e.createMeet)
      'conferenceData': {
        'createRequest': {
          'requestId': e.id,
          'conferenceSolutionKey': {'type': 'hangoutsMeet'},
        },
      },
    if (e.rrule != null && e.rrule!.isNotEmpty)
      'recurrence': ['RRULE:${e.rrule}'],
  };
  return body;
}

class MappedTask {
  MappedTask({required this.companion, required this.remoteEtag});
  final TasksCompanion companion;
  final String? remoteEtag;
}

MappedTask taskFromGoogle(
  Map<String, dynamic> g,
  String? listId,
  String localId,
) {
  String? dueDate;
  final due = g['due'] as String?;
  if (due != null) dueDate = due.substring(0, 10);
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  return MappedTask(
    companion: TasksCompanion(
      id: Value(localId),
      listId: Value(listId),
      title: Value((g['title'] as String?) ?? ''),
      notes: Value(g['notes'] as String?),
      dueDate: Value(dueDate),
      completedAt: g['status'] == 'completed'
          ? Value(
              DateTime.tryParse(
                    g['completed'] as String? ?? '',
                  )?.toUtc().millisecondsSinceEpoch ??
                  now,
            )
          : const Value(null),
      deletedAt: (g['deleted'] == true) ? Value(now) : const Value(null),
      remoteId: Value(g['id'] as String?),
      remoteEtag: Value(g['etag'] as String?),
      dirty: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
    remoteEtag: g['etag'] as String?,
  );
}

/// Ensures an all-day event's end date is EXCLUSIVE (Google-style) when
/// serializing to the Calendar API. Legacy rows with end==start become a
/// single day.
String? _exclusiveAllDayEnd(Event e) {
  final start = e.startDate;
  var end = e.endDate ?? start;
  if (start != null && (end == null || end.compareTo(start) <= 0)) {
    final p = start.split('-');
    final d = DateTime.utc(
      int.parse(p[0]),
      int.parse(p[1]),
      int.parse(p[2]),
    ).add(const Duration(days: 1));
    end = dateKey(d);
  }
  return end;
}

Map<String, dynamic> taskToGoogle(Task t) => {
  'title': t.title,
  if (t.notes != null) 'notes': t.notes,
  if (t.dueDate != null) 'due': '${t.dueDate}T00:00:00.000Z',
  if (t.completedAt != null)
    'status': 'completed'
  else if (t.deletedAt != null)
    'deleted': true,
};
