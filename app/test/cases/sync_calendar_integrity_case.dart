import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/remote/google_api_client.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

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

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

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

void main() {
  test('full resync uses unbounded eventsList and v2 token key', () async {
    final db = _db();
    addTearDown(db.close);
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
      final db = _db();
      addTearDown(db.close);
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
    final db = _db();
    addTearDown(db.close);
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

  test('dirty local exception row is preserved', () async {
    final db = _db();
    addTearDown(db.close);
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
    final db = _db();
    addTearDown(db.close);
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
    final db = _db();
    addTearDown(db.close);
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
}
