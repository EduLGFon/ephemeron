import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/remote/google_api_client.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fixtures.dart';

class _FakeGoogle implements GoogleApiClient {
  List<Map<String, dynamic>> calendars = [];
  Map<String, List<Map<String, dynamic>>> eventsByCal = {};
  Map<String, int> failStatus = {};
  String nextToken = 'tokv2';
  String? lastSyncTokenSeen;
  String? lastTimeMin;
  String? lastTimeMax;

  @override
  Future<List<Map<String, dynamic>>> calendarList() async => List.of(calendars);

  @override
  Future<CalendarPage> eventsList(
    String calendarId, {
    String? syncToken,
    String? timeMin,
    String? timeMax,
    bool singleEvents = false,
    bool showDeleted = true,
  }) async {
    lastSyncTokenSeen = syncToken;
    lastTimeMin = timeMin;
    lastTimeMax = timeMax;
    if (failStatus.containsKey(calendarId)) {
      throw GoogleApiException(failStatus[calendarId]!, 'boom');
    }
    return CalendarPage(
      items: List.of(eventsByCal[calendarId] ?? const []),
      nextSyncToken: nextToken,
    );
  }

  @override
  Future<Map<String, dynamic>> eventInsert(
    String c,
    Map<String, dynamic> b,
  ) async => {'id': 'r', 'etag': 'e'};
  @override
  Future<Map<String, dynamic>> eventPatch(
    String c,
    String e,
    Map<String, dynamic> b, {
    String? etag,
  }) async => {'etag': 'e'};
  @override
  Future<Map<String, dynamic>> eventMove(String s, String e, String d) async =>
      {'id': e, 'etag': 'e'};
  @override
  Future<void> eventDelete(String c, String e) async {}
  @override
  Future<List<Map<String, dynamic>>> taskLists() async => [];
  @override
  Future<Map<String, dynamic>> taskListCreate(String title) async => {
    'id': 'l',
    'etag': 'e',
  };
  @override
  Future<Map<String, dynamic>> taskListPatch(
    String listId,
    String title,
  ) async => {'id': listId, 'etag': 'e'};
  @override
  Future<void> taskListDelete(String listId) async {}
  @override
  Future<TasksPage> tasksList(String id, {String? updatedMin}) async =>
      TasksPage(items: [], nextUpdatedMin: 'now');
  @override
  Future<Map<String, dynamic>> taskInsert(
    String l,
    Map<String, dynamic> b,
  ) async => {'id': 't', 'etag': 'e'};
  @override
  Future<Map<String, dynamic>> taskPatch(
    String l,
    String t,
    Map<String, dynamic> b, {
    String? etag,
  }) async => {'etag': 'e'};
  @override
  Future<Map<String, dynamic>> taskMove(String s, String t, String d) async => {
    'id': t,
    'etag': 'e',
  };
  @override
  Future<void> taskDelete(String l, String t) async {}
}

late AppDatabase db;

Future<void> _cal(AppDatabase db, String id, {String? remoteId}) async {
  remoteId ??= 'remote-$id';
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: id,
          remoteId: Value(remoteId),
          name: 'c',
          source: Value('google'),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _seedEvent(
  AppDatabase db,
  String id, {
  required String calendarId,
  String? remoteId,
  bool dirty = false,
  List<String> attendeeEmails = const [],
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: id,
          calendarId: calendarId,
          remoteId: Value(remoteId),
          dirty: Value(dirty),
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (var i = 0; i < attendeeEmails.length; i++) {
    await db
        .into(db.eventAttendees)
        .insert(
          EventAttendeesCompanion.insert(
            id: '$id-attendee-$i',
            eventId: id,
            email: attendeeEmails[i],
          ),
        );
  }
}

Future<List<String>> _attendeeEmailsForLocal(
  AppDatabase db,
  String eventId,
) async {
  final rows = await (db.select(
    db.eventAttendees,
  )..where((a) => a.eventId.equals(eventId))).get();
  return [for (final row in rows) row.email]..sort();
}

Future<List<String>> _attendeeEmailsForRemote(
  AppDatabase db,
  String remoteId,
) async {
  final event = await (db.select(
    db.events,
  )..where((e) => e.remoteId.equals(remoteId))).getSingle();
  return _attendeeEmailsForLocal(db, event.id);
}

void main() {
  setUpAll(() => db = newTestDb());
  setUp(() => resetTestDb(db));
  tearDownAll(() => db.close());
  test('full resync uses unbounded eventsList and v2 token key', () async {
    await _cal(db, 'c1');
    final fake = _FakeGoogle()..eventsByCal['remote-c1'] = [];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    expect(fake.lastTimeMin, isNull);
    expect(fake.lastTimeMax, isNull);
    final tokenRow = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals('cal:v2:c1:token'))).getSingleOrNull();
    expect(tokenRow?.value, 'tokv2');
  });

  test(
    'timed exception mapping, cancelled suppression, malformed item',
    () async {
      await _cal(db, 'c1');
      final movedStart = DateTime.utc(2026, 3, 4, 11);
      final fake = _FakeGoogle()
        ..eventsByCal['remote-c1'] = [
          {
            'id': 'm1',
            'etag': 'a',
            'summary': 'Master',
            'status': 'confirmed',
            'start': {'dateTime': '2026-03-02T09:00:00Z'},
            'end': {'dateTime': '2026-03-02T10:00:00Z'},
            'recurrence': ['RRULE:FREQ=DAILY;COUNT=5'],
          },
          {
            'id': 'exMoved',
            'etag': 'b',
            'summary': 'Moved',
            'status': 'confirmed',
            'recurringEventId': 'm1',
            'originalStartTime': {'dateTime': '2026-03-03T09:00:00Z'},
            'start': {'dateTime': '2026-03-04T11:00:00Z'},
            'end': {'dateTime': '2026-03-04T12:00:00Z'},
          },
          {
            'id': 'exCancelled',
            'etag': 'c',
            'status': 'cancelled',
            'recurringEventId': 'm1',
            'originalStartTime': {'dateTime': '2026-03-05T09:00:00Z'},
          },
          {
            'id': 'bad',
            'etag': 'd',
            'summary': 'Bad',
            'status': 'confirmed',
            'recurringEventId': 'm1',
            'originalStartTime': {'dateTime': 'not-a-date'},
            'start': {'dateTime': '2026-03-06T09:00:00Z'},
            'end': {'dateTime': '2026-03-06T10:00:00Z'},
          },
          {
            'id': 'single',
            'etag': 'e',
            'summary': 'Single',
            'status': 'confirmed',
            'start': {'dateTime': '2026-03-07T09:00:00Z'},
            'end': {'dateTime': '2026-03-07T10:00:00Z'},
          },
        ];
      final engine = SyncEngine(db, clientFactory: () => fake);
      await engine.syncNow();

      final master = await (db.select(
        db.events,
      )..where((e) => e.remoteId.equals('m1'))).getSingle();
      final moved = await (db.select(
        db.events,
      )..where((e) => e.remoteId.equals('exMoved'))).getSingle();
      expect(moved.recurringMasterId, master.id);
      expect(
        moved.originalStart,
        DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch,
      );

      final cancelled = await (db.select(
        db.events,
      )..where((e) => e.remoteId.equals('exCancelled'))).getSingle();
      expect(cancelled.status, 'cancelled');
      expect(cancelled.deletedAt, isNull);

      final single = await (db.select(
        db.events,
      )..where((e) => e.remoteId.equals('single'))).getSingle();
      expect(single, isNotNull);

      // collector check
      final repo = OccurrenceRepository(db);
      await repo.rebuildWindow(
        windowStartUtc: DateTime.utc(2026, 3, 1),
        windowEndUtc: DateTime.utc(2026, 3, 8),
      );
      expect(await repo.occurrencesForDay('2026-03-03'), isEmpty);
      final movedDayRows = await repo.occurrencesForDay('2026-03-04');
      expect(
        movedDayRows
            .where((r) => r.startUtc == movedStart.millisecondsSinceEpoch)
            .length,
        1,
      );
    },
  );

  test('all-day exception mapping suppresses original', () async {
    await _cal(db, 'c1');
    final fake = _FakeGoogle()
      ..eventsByCal['remote-c1'] = [
        {
          'id': 'm1',
          'etag': 'a',
          'summary': 'Master',
          'status': 'confirmed',
          'start': {'date': '2026-03-02'},
          'end': {'date': '2026-03-03'},
          'recurrence': ['RRULE:FREQ=DAILY;COUNT=5'],
        },
        {
          'id': 'exMoved',
          'etag': 'b',
          'summary': 'Moved',
          'status': 'confirmed',
          'recurringEventId': 'm1',
          'originalStartTime': {'date': '2026-03-03'},
          'start': {'date': '2026-03-10'},
          'end': {'date': '2026-03-11'},
        },
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    final master = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('m1'))).getSingle();
    final moved = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('exMoved'))).getSingle();
    expect(moved.recurringMasterId, master.id);
    expect(
      moved.originalStart,
      DateTime.utc(2026, 3, 3).millisecondsSinceEpoch,
    );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 12),
    );
    expect(await repo.occurrencesForDay('2026-03-03'), isEmpty);
    expect((await repo.occurrencesForDay('2026-03-10')).length, 1);
  });

  test('remote exception omitting location/Meet keeps master values', () async {
    await _cal(db, 'c1');
    final master = {
      'id': 'm1',
      'etag': 'a',
      'summary': 'Master',
      'status': 'confirmed',
      'start': {'dateTime': '2026-03-02T09:00:00Z'},
      'end': {'dateTime': '2026-03-02T10:00:00Z'},
      'recurrence': ['RRULE:FREQ=DAILY;COUNT=5'],
      'location': 'Room 1',
      'hangoutLink': 'https://meet.google.com/abc-defg-hij',
      'visibility': 'public',
      'transparency': 'opaque',
    };
    final exception = {
      'id': 'exMoved',
      'etag': 'b',
      'summary': 'Moved',
      'status': 'confirmed',
      'recurringEventId': 'm1',
      'originalStartTime': {'dateTime': '2026-03-03T09:00:00Z'},
      'start': {'dateTime': '2026-03-04T11:00:00Z'},
      'end': {'dateTime': '2026-03-04T12:00:00Z'},
    };
    final fake = _FakeGoogle()..eventsByCal['remote-c1'] = [master, exception];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    var moved = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('exMoved'))).getSingle();
    expect(moved.location, 'Room 1');
    expect(moved.meetUrl, 'https://meet.google.com/abc-defg-hij');
    expect(moved.visibility, 'public');
    expect(moved.transparency, 'opaque');

    // A later pull omits the same fields. It must not null or replace them.
    fake.eventsByCal['remote-c1'] = [
      master,
      {
        ...exception,
        'etag': 'c',
        'start': {'dateTime': '2026-03-05T11:00:00Z'},
        'end': {'dateTime': '2026-03-05T12:00:00Z'},
      },
    ];
    await engine.syncNow();
    moved = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('exMoved'))).getSingle();
    expect(moved.location, 'Room 1');
    expect(moved.meetUrl, 'https://meet.google.com/abc-defg-hij');
    expect(moved.startUtc, DateTime.utc(2026, 3, 5, 11).millisecondsSinceEpoch);
  });

  test('cancelled remote exception keeps local inherited fields', () async {
    await _cal(db, 'c1');
    final master = {
      'id': 'm1',
      'etag': 'a',
      'summary': 'Master',
      'status': 'confirmed',
      'start': {'dateTime': '2026-03-02T09:00:00Z'},
      'end': {'dateTime': '2026-03-02T10:00:00Z'},
      'recurrence': ['RRULE:FREQ=DAILY;COUNT=5'],
      'location': 'Room 1',
      'hangoutLink': 'https://meet.google.com/abc-defg-hij',
      'visibility': 'public',
      'transparency': 'opaque',
    };
    final exception = {
      'id': 'exMoved',
      'etag': 'b',
      'summary': 'Moved',
      'status': 'confirmed',
      'recurringEventId': 'm1',
      'originalStartTime': {'dateTime': '2026-03-03T09:00:00Z'},
      'start': {'dateTime': '2026-03-04T11:00:00Z'},
      'end': {'dateTime': '2026-03-04T12:00:00Z'},
    };
    final fake = _FakeGoogle()..eventsByCal['remote-c1'] = [master, exception];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    await (db.update(
      db.events,
    )..where((e) => e.remoteId.equals('exMoved'))).write(
      const EventsCompanion(
        reminders: Value('[5]'),
        alarmPreset: Value('notification'),
      ),
    );
    fake.eventsByCal['remote-c1'] = [
      master,
      {
        ...exception,
        'etag': 'c',
        'status': 'cancelled',
        'start': null,
        'end': null,
      },
    ];
    await engine.syncNow();

    final cancelled = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('exMoved'))).getSingle();
    expect(cancelled.status, 'cancelled');
    expect(cancelled.location, 'Room 1');
    expect(cancelled.meetUrl, 'https://meet.google.com/abc-defg-hij');
    expect(cancelled.visibility, 'public');
    expect(cancelled.transparency, 'opaque');
    expect(cancelled.reminders, '[5]');
    expect(cancelled.alarmPreset, 'notification');
  });

  test('dirty local exception row is preserved', () async {
    await _cal(db, 'c1');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'local-ex',
            calendarId: 'c1',
            remoteId: Value('exMoved'),
            title: Value('Local'),
            dirty: Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final fake = _FakeGoogle()
      ..eventsByCal['remote-c1'] = [
        {
          'id': 'm1',
          'etag': 'a',
          'summary': 'Master',
          'status': 'confirmed',
          'start': {'dateTime': '2026-03-02T09:00:00Z'},
          'end': {'dateTime': '2026-03-02T10:00:00Z'},
          'recurrence': ['RRULE:FREQ=DAILY;COUNT=3'],
        },
        {
          'id': 'exMoved',
          'etag': 'b',
          'summary': 'RemoteMoved',
          'status': 'confirmed',
          'recurringEventId': 'm1',
          'originalStartTime': {'dateTime': '2026-03-03T09:00:00Z'},
          'start': {'dateTime': '2026-03-04T11:00:00Z'},
          'end': {'dateTime': '2026-03-04T12:00:00Z'},
        },
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    final row = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('exMoved'))).getSingle();
    expect(row.title, 'Local');
  });

  test('per-calendar isolation', () async {
    await _cal(db, 'c1');
    await _cal(db, 'c2', remoteId: 'remote-c2');
    final fake = _FakeGoogle()
      ..failStatus['c1'] = 500
      ..eventsByCal['remote-c2'] = [
        {
          'id': 'g1',
          'etag': 'a',
          'summary': 'Ok',
          'status': 'confirmed',
          'start': {'dateTime': '2026-03-02T09:00:00Z'},
          'end': {'dateTime': '2026-03-02T10:00:00Z'},
        },
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    final rows = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('g1'))).get();
    expect(rows, hasLength(1));
  });

  test('v2 token sent on next pull', () async {
    await _cal(db, 'c1');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.syncState)
        .insert(
          SyncStateCompanion.insert(
            key: 'cal:v2:c1:token',
            value: Value('saved-tok'),
            lastSyncAt: Value(now),
          ),
        );
    final fake = _FakeGoogle()..eventsByCal['remote-c1'] = [];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    expect(fake.lastSyncTokenSeen, 'saved-tok');
  });

  test('full resync clears attendees before deleting parent events', () async {
    await _cal(db, 'c1');
    // Two synced events with attendee rows and no v2 token: the full resync
    // hard-deletes both parents, which violates the attendee FK without a
    // dependent delete first.
    await _seedEvent(
      db,
      'local-one',
      calendarId: 'c1',
      remoteId: 'ev-one',
      attendeeEmails: ['old-one@example.test', 'old-two@example.test'],
    );
    await _seedEvent(
      db,
      'local-two',
      calendarId: 'c1',
      remoteId: 'ev-two',
      attendeeEmails: ['old-three@example.test'],
    );
    final fake = _FakeGoogle()
      ..eventsByCal['remote-c1'] = [
        {
          'id': 'ev-one',
          'etag': 'a',
          'summary': 'One',
          'status': 'confirmed',
          'start': {'dateTime': '2026-03-02T09:00:00Z'},
          'end': {'dateTime': '2026-03-02T10:00:00Z'},
          'attendees': [
            {'email': 'new-one@example.test', 'responseStatus': 'accepted'},
            {'email': 'new-two@example.test', 'responseStatus': 'declined'},
          ],
        },
        {
          'id': 'ev-three',
          'etag': 'b',
          'summary': 'Three',
          'status': 'confirmed',
          'start': {'dateTime': '2026-03-03T09:00:00Z'},
          'end': {'dateTime': '2026-03-03T10:00:00Z'},
          'attendees': [
            {'email': 'new-three@example.test', 'responseStatus': 'tentative'},
          ],
        },
      ];

    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    expect(engine.status, SyncStatus.synced);
    expect(engine.errorKind, SyncErrorKind.none);
    expect(await engine.watchSyncStateIssues().first, isEmpty);
    final events = await db.select(db.events).get();
    expect(
      events.map((e) => e.remoteId),
      unorderedEquals(['ev-one', 'ev-three']),
    );
    expect(await _attendeeEmailsForRemote(db, 'ev-one'), [
      'new-one@example.test',
      'new-two@example.test',
    ]);
    expect(await _attendeeEmailsForRemote(db, 'ev-three'), [
      'new-three@example.test',
    ]);
    expect(await db.select(db.eventAttendees).get(), hasLength(3));
    final token = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals('cal:v2:c1:token'))).getSingleOrNull();
    expect(token?.value, 'tokv2');
  });

  test(
    'full resync keeps dirty rows and clears attendees for deleted events',
    () async {
      await _cal(db, 'c1');
      await _seedEvent(
        db,
        'keep',
        calendarId: 'c1',
        remoteId: 'ev-keep',
        dirty: true,
        attendeeEmails: ['local-owner@example.test'],
      );
      await _seedEvent(
        db,
        'gone',
        calendarId: 'c1',
        remoteId: 'ev-gone',
        attendeeEmails: ['gone-one@example.test', 'gone-two@example.test'],
      );
      await _seedEvent(
        db,
        'gone-empty',
        calendarId: 'c1',
        remoteId: 'ev-gone-empty',
      );
      final fake = _FakeGoogle()
        ..eventsByCal['remote-c1'] = [
          {
            'id': 'ev-new',
            'etag': 'c',
            'summary': 'New',
            'status': 'confirmed',
            'start': {'dateTime': '2026-03-04T09:00:00Z'},
            'end': {'dateTime': '2026-03-04T10:00:00Z'},
            'attendees': [
              {'email': 'new-owner@example.test', 'responseStatus': 'accepted'},
            ],
          },
        ];

      final engine = SyncEngine(db, clientFactory: () => fake);
      await engine.syncNow();

      expect(engine.status, SyncStatus.synced);
      expect(engine.errorKind, SyncErrorKind.none);
      final events = await db.select(db.events).get();
      expect(
        events.map((e) => e.remoteId),
        unorderedEquals(['ev-keep', 'ev-new']),
      );
      final kept = events.singleWhere((e) => e.remoteId == 'ev-keep');
      expect(kept.dirty, isTrue);
      expect(await _attendeeEmailsForLocal(db, kept.id), [
        'local-owner@example.test',
      ]);
      expect(await _attendeeEmailsForRemote(db, 'ev-new'), [
        'new-owner@example.test',
      ]);
      expect(await db.select(db.eventAttendees).get(), hasLength(2));
    },
  );

  test('full resync deletes attendee rows across multiple chunks', () async {
    await _cal(db, 'c1');
    const bulkEvents = 520; // More than one 500-id delete chunk.
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.batch((batch) {
      for (var i = 0; i < bulkEvents; i++) {
        batch.insert(
          db.events,
          EventsCompanion.insert(
            id: 'bulk-$i',
            calendarId: 'c1',
            remoteId: Value('remote-bulk-$i'),
            createdAt: now,
            updatedAt: now,
          ),
        );
        batch.insert(
          db.eventAttendees,
          EventAttendeesCompanion.insert(
            id: 'bulk-attendee-$i',
            eventId: 'bulk-$i',
            email: 'person-$i@example.test',
          ),
        );
      }
      batch.insert(
        db.events,
        EventsCompanion.insert(
          id: 'dirty-keep',
          calendarId: 'c1',
          remoteId: const Value('remote-dirty'),
          dirty: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      batch.insert(
        db.eventAttendees,
        EventAttendeesCompanion.insert(
          id: 'dirty-attendee',
          eventId: 'dirty-keep',
          email: 'local-owner@example.test',
        ),
      );
    });
    final fake = _FakeGoogle()..eventsByCal['remote-c1'] = [];

    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    expect(engine.status, SyncStatus.synced);
    expect(engine.errorKind, SyncErrorKind.none);
    final events = await db.select(db.events).get();
    expect(events, hasLength(1));
    expect(events.single.id, 'dirty-keep');
    final attendees = await db.select(db.eventAttendees).get();
    expect(attendees, hasLength(1));
    expect(attendees.single.eventId, 'dirty-keep');
    final token = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals('cal:v2:c1:token'))).getSingleOrNull();
    expect(token?.value, 'tokv2');
  });
}
