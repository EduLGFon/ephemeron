// Fake-server suite: 410 resets, etag conflicts, 429 backoff, offline
// queues, partial failure, idempotent resume.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/remote/google_api_client.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fixtures.dart';

late AppDatabase db;

class FakeGoogle implements GoogleApiClient {
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> instances = [];
  List<Map<String, dynamic>> calendars = [];
  List<Map<String, dynamic>> taskListsResult = [];
  final List<String> pulledCalendars = [];
  final List<String> pulledTaskLists = [];
  final List<String> patchedEventIds = [];
  final List<String> deletedEvents = [];
  Map<String, dynamic>? lastPatchBody;
  final List<String?> etagHistory = [];
  String? lastSyncTokenSeen;
  String? lastEtagSeen;
  String? lastInstanceTimeMin;
  String? lastInstanceTimeMax;
  bool? lastInstanceShowDeleted;
  int singleEventsCalls = 0;
  bool fail410Once = false;
  int fail410OnIncremental = 0;
  int fullFetchCount = 0;
  bool fail429Once = false;
  bool fail412Once = false;
  int inserts = 0;
  int patches = 0;
  int eventMoves = 0;
  int taskMoves = 0;
  int taskListCreates = 0;
  int taskListPatches = 0;
  String? lastTaskListTitle;
  final List<String> patchedTaskLists = [];
  final List<String> deletedTaskLists = [];
  final List<String> deletedTasks = [];
  int? retryAfterSec;

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
    if (singleEvents) {
      singleEventsCalls++;
      lastInstanceTimeMin = timeMin;
      lastInstanceTimeMax = timeMax;
      lastInstanceShowDeleted = showDeleted;
      return CalendarPage(items: List.of(instances));
    }
    if (syncToken == null) {
      fullFetchCount++;
    } else if (fail410OnIncremental > 0) {
      fail410OnIncremental--;
      throw GoogleApiException(410, 'gone');
    }
    if (fail410Once) {
      fail410Once = false;
      throw GoogleApiException(410, 'gone');
    }
    pulledCalendars.add(calendarId);
    lastSyncTokenSeen = syncToken;
    return CalendarPage(items: List.of(events), nextSyncToken: 'tok123');
  }

  @override
  Future<Map<String, dynamic>> eventInsert(
    String calendarId,
    Map<String, dynamic> body,
  ) async {
    inserts++;
    return {'id': 'r$inserts', 'etag': 'e1'};
  }

  @override
  Future<Map<String, dynamic>> eventPatch(
    String calendarId,
    String eventId,
    Map<String, dynamic> body, {
    String? etag,
  }) async {
    lastEtagSeen = etag;
    etagHistory.add(etag);
    if (fail412Once) {
      fail412Once = false;
      throw GoogleApiException(412, 'etag mismatch');
    }
    patches++;
    patchedEventIds.add(eventId);
    lastPatchBody = body;
    return {'id': eventId, 'etag': 'e$patches'};
  }

  @override
  Future<Map<String, dynamic>> eventMove(
    String sourceCalendarId,
    String eventId,
    String destinationCalendarId,
  ) async {
    eventMoves++;
    return {'id': eventId, 'etag': 'moved$eventMoves'};
  }

  @override
  Future<void> eventDelete(String c, String e) async {
    deletedEvents.add(e);
  }

  @override
  Future<List<Map<String, dynamic>>> taskLists() async =>
      List.of(taskListsResult);

  @override
  Future<Map<String, dynamic>> taskListCreate(String title) async {
    taskListCreates++;
    lastTaskListTitle = title;
    return {
      'id': 'rl-new-$taskListCreates',
      'etag': 'list-etag-$taskListCreates',
    };
  }

  @override
  Future<Map<String, dynamic>> taskListPatch(
    String listId,
    String title,
  ) async {
    taskListPatches++;
    lastTaskListTitle = title;
    patchedTaskLists.add(listId);
    return {'id': listId, 'etag': 'list-etag-p$taskListPatches'};
  }

  @override
  Future<void> taskListDelete(String listId) async {
    deletedTaskLists.add(listId);
  }

  @override
  Future<TasksPage> tasksList(String id, {String? updatedMin}) async {
    pulledTaskLists.add(id);
    return TasksPage(items: [], nextUpdatedMin: 'now');
  }

  @override
  Future<Map<String, dynamic>> taskInsert(
    String l,
    Map<String, dynamic> b,
  ) async => {'id': 't1', 'etag': 'e1'};

  @override
  Future<Map<String, dynamic>> taskPatch(
    String l,
    String t,
    Map<String, dynamic> b, {
    String? etag,
  }) async => {'etag': 'e2'};

  @override
  Future<Map<String, dynamic>> taskMove(
    String sourceTaskListId,
    String taskId,
    String destinationTaskListId,
  ) async {
    taskMoves++;
    return {'id': taskId, 'etag': 'task-moved$taskMoves'};
  }

  @override
  Future<void> taskDelete(String l, String t) async {
    deletedTasks.add(t);
  }
}

Future<String> _cal(AppDatabase db, {String source = 'google'}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: 'c1',
          remoteId: Value('cal-remote'),
          name: 'c',
          source: Value(source),
          createdAt: now,
          updatedAt: now,
        ),
      );
  return 'c1';
}

Future<void> _seedToken(AppDatabase db) async {
  await db
      .into(db.syncState)
      .insert(
        SyncStateCompanion.insert(
          key: 'cal:v2:c1:token',
          value: const Value('t0'),
        ),
      );
}

Future<void> _seedMaster(AppDatabase db) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: 'm1',
          calendarId: 'c1',
          title: const Value('Master'),
          startUtc: Value(DateTime.utc(2026, 3, 2, 9).millisecondsSinceEpoch),
          endUtc: Value(DateTime.utc(2026, 3, 2, 10).millisecondsSinceEpoch),
          tzId: const Value('UTC'),
          rrule: const Value('FREQ=DAILY;COUNT=5'),
          remoteId: const Value('master-remote'),
          remoteEtag: const Value('me'),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _seedException(
  AppDatabase db, {
  required String id,
  required DateTime originalStart,
  String? remoteId,
  String status = 'confirmed',
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: id,
          calendarId: 'c1',
          title: const Value('Exception'),
          startUtc: Value(originalStart.millisecondsSinceEpoch),
          endUtc: Value(
            originalStart.add(const Duration(hours: 1)).millisecondsSinceEpoch,
          ),
          tzId: const Value('UTC'),
          recurringMasterId: const Value('m1'),
          originalStart: Value(originalStart.millisecondsSinceEpoch),
          status: Value(status),
          remoteId: Value(remoteId),
          remoteEtag: const Value('ex-etag'),
          dirty: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Map<String, dynamic> _instance(
  String id,
  DateTime originalStart, {
  String masterRemoteId = 'master-remote',
}) => {
  'id': id,
  'etag': 'ie-$id',
  'status': 'confirmed',
  'summary': 'Master',
  'recurringEventId': masterRemoteId,
  'originalStartTime': {'dateTime': originalStart.toIso8601String()},
  'start': {'dateTime': originalStart.toIso8601String()},
  'end': {
    'dateTime': originalStart.add(const Duration(hours: 1)).toIso8601String(),
  },
};

Map<String, dynamic> _cancelledInstance(
  String id,
  DateTime originalStart, {
  String masterRemoteId = 'master-remote',
}) => {
  'id': id,
  'etag': 'ie-$id',
  'status': 'cancelled',
  'recurringEventId': masterRemoteId,
  'originalStartTime': {'dateTime': originalStart.toIso8601String()},
};

void main() {
  setUpAll(() => db = newTestDb());
  setUp(() => resetTestDb(db));
  tearDownAll(() => db.close());

  test('pull saves token, second pull sends it', () async {
    await _cal(db);
    final fake = FakeGoogle()
      ..events = [
        {
          'id': 'g1',
          'etag': 'a',
          'summary': 'Meet',
          'status': 'confirmed',
          'start': {'dateTime': '2026-03-03T09:00:00Z'},
          'end': {'dateTime': '2026-03-03T10:00:00Z'},
        },
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    expect(engine.status, SyncStatus.synced);
    await engine.syncNow();
    expect(fake.lastSyncTokenSeen, 'tok123');
    // Idempotent: single row for the remote event.
    final rows = await db.select(db.events).get();
    expect(rows.where((e) => e.remoteId == 'g1'), hasLength(1));
  });

  test('410 clears synced rows but keeps dirty local rows', () async {
    await _cal(db);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'synced',
            calendarId: 'c1',
            remoteId: Value('g-old'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'dirty',
            calendarId: 'c1',
            createdAt: now,
            updatedAt: now,
            dirty: Value(true),
          ),
        );
    final fake = FakeGoogle()
      ..fail410Once = true
      ..events = [];
    // Seed a token so the 410 path triggers.
    await db
        .into(db.syncState)
        .insert(
          SyncStateCompanion.insert(
            key: 'cal:v2:c1:token',
            value: Value('old-tok'),
          ),
        );
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    final rows = await db.select(db.events).get();
    expect(rows.map((e) => e.id), contains('dirty'));
    expect(rows.map((e) => e.id), isNot(contains('synced')));
  });

  test('410 cooldown prevents repeated full resync', () async {
    await _cal(db);
    await _seedToken(db);
    final fake = FakeGoogle()
      ..fail410OnIncremental = 1
      ..events = [
        {
          'id': 'g1',
          'etag': 'a',
          'summary': 'Meet',
          'status': 'confirmed',
          'start': {'dateTime': '2026-03-03T09:00:00Z'},
          'end': {'dateTime': '2026-03-03T10:00:00Z'},
        },
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);

    await engine.syncNow();
    expect(fake.fullFetchCount, 1);
    final afterFirst = await db.select(db.events).get();
    expect(afterFirst.where((e) => e.remoteId == 'g1'), hasLength(1));

    await engine.syncNow();
    expect(fake.fullFetchCount, 1);
    final meta = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals('cal:c1:meta'))).getSingle();
    expect(meta.lastError, 'Google 410');
    final afterSecond = await db.select(db.events).get();
    expect(afterSecond.where((e) => e.remoteId == 'g1'), hasLength(1));

    await (db.delete(
      db.syncState,
    )..where((s) => s.key.equals('cal:v2:c1:goneAt'))).go();
    fake.fail410OnIncremental = 1;
    await engine.syncNow();
    expect(fake.fullFetchCount, 2);
    final afterThird = await db.select(db.events).get();
    expect(afterThird.where((e) => e.remoteId == 'g1'), hasLength(1));
  });

  test('push insert assigns remote id; patch sends etag', () async {
    await _cal(db);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'e1',
            calendarId: 'c1',
            title: Value('New'),
            createdAt: now,
            updatedAt: now,
            dirty: Value(true),
          ),
        );
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            id: 'op1',
            entity: 'event',
            entityId: 'e1',
            op: 'create',
            createdAt: now,
          ),
        );
    final fake = FakeGoogle()
      ..events = [
        {'id': 'r1', 'etag': 'e1', 'summary': 'New', 'status': 'confirmed'},
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    expect(fake.inserts, 1);
    expect((await db.select(db.outbox).get()), isEmpty);
    final rows = await (db.select(
      db.events,
    )..where((t) => t.remoteId.equals('r1'))).get();
    expect(rows, hasLength(1));
    expect(rows.single.dirty, isFalse);
  });

  test('412 conflict refetches and reapplies with new etag', () async {
    await _cal(db);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'e1',
            calendarId: 'c1',
            title: Value('Mine'),
            remoteId: Value('g1'),
            remoteEtag: Value('stale'),
            createdAt: now,
            updatedAt: now,
            dirty: Value(true),
          ),
        );
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            id: 'op1',
            entity: 'event',
            entityId: 'e1',
            op: 'update',
            createdAt: now,
          ),
        );
    final fake = FakeGoogle()
      ..fail412Once = true
      ..events = [
        {
          'id': 'g1',
          'etag': 'fresh',
          'summary': 'Theirs',
          'status': 'confirmed',
          'start': {'dateTime': '2026-03-03T09:00:00Z'},
          'end': {'dateTime': '2026-03-03T10:00:00Z'},
        },
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    // First attempt stale, retry with fresh etag.
    expect(fake.lastEtagSeen, 'fresh');
    expect((await db.select(db.outbox).get()), isEmpty);
  });

  test('429 sets nextTryAt; retryFailed resets', () async {
    await _cal(db);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'e1',
            calendarId: 'c1',
            remoteId: Value('g1'),
            remoteEtag: Value('e0'),
            createdAt: now,
            updatedAt: now,
            dirty: Value(true),
          ),
        );
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            id: 'op1',
            entity: 'event',
            entityId: 'e1',
            op: 'update',
            createdAt: now,
          ),
        );
    final fake = _RateLimitedOnce();
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    final op = await (db.select(
      db.outbox,
    )..where((o) => o.id.equals('op1'))).getSingle();
    expect(op.nextTryAt, isNotNull);
    await engine.retryFailed('op1');
    final reset = await (db.select(
      db.outbox,
    )..where((o) => o.id.equals('op1'))).getSingle();
    expect(reset.nextTryAt, isNull);
    expect(reset.attempts, 0);
  });

  test('single occurrence edit patches the Google instance', () async {
    await _cal(db);
    await _seedToken(db);
    await _seedMaster(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final exId = await repo.editOccurrence(
      'm1',
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      title: 'Special',
    );
    final before = await repo.getEvent(exId);
    expect(before!.dirty, isTrue);
    await repo.setAttendees(exId, ['ex@example.com']);
    final queued = await db.select(db.outbox).get();
    expect(queued.map((o) => o.entityId), [exId]);
    expect(queued.single.op, 'update');

    final fake = FakeGoogle()
      ..instances = [_instance('instance-1', DateTime.utc(2026, 3, 3, 9))];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    expect(fake.singleEventsCalls, 1);
    expect(fake.lastInstanceShowDeleted, isTrue);
    expect(fake.lastInstanceTimeMin, isNotNull);
    expect(fake.lastInstanceTimeMax, isNotNull);
    expect(fake.patchedEventIds, ['instance-1']);
    expect(fake.lastPatchBody?['summary'], 'Special');
    expect(fake.lastPatchBody?['attendees'], [
      {'email': 'ex@example.com'},
    ]);
    final ex = await repo.getEvent(exId);
    expect(ex!.remoteId, 'instance-1');
    expect(ex.dirty, isFalse);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(engine.status, SyncStatus.synced);
  });

  test(
    'exception push creates a local master before instance lookup',
    () async {
      await _cal(db);
      await _seedToken(db);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              id: 'm-local',
              calendarId: 'c1',
              title: const Value('Master'),
              startUtc: Value(
                DateTime.utc(2026, 3, 2, 9).millisecondsSinceEpoch,
              ),
              endUtc: Value(
                DateTime.utc(2026, 3, 2, 10).millisecondsSinceEpoch,
              ),
              rrule: const Value('FREQ=DAILY;COUNT=5'),
              dirty: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final repo = EventRepository(db, OccurrenceRepository(db));
      final exId = await repo.editOccurrence(
        'm-local',
        DateTime.utc(2026, 3, 3, 9),
        scope: EditScope.single,
        title: 'Special',
      );
      final fake = FakeGoogle()
        ..instances = [
          _instance(
            'instance-1',
            DateTime.utc(2026, 3, 3, 9),
            masterRemoteId: 'r1',
          ),
        ];
      final engine = SyncEngine(db, clientFactory: () => fake);
      await engine.syncNow();

      expect(fake.inserts, 1);
      expect(fake.patchedEventIds, ['instance-1']);
      final master = await repo.getEvent('m-local');
      expect(master!.remoteId, 'r1');
      expect(master.dirty, isFalse);
      final ex = await repo.getEvent(exId);
      expect(ex!.remoteId, 'instance-1');
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );

  test('single occurrence delete removes the Google instance once', () async {
    await _cal(db);
    await _seedToken(db);
    await _seedMaster(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.deleteOccurrence(
      'm1',
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
    );
    final queued = await db.select(db.outbox).get();
    expect(queued.single.op, 'delete');
    expect(queued.single.entityId, isNot('m1'));

    final fake = FakeGoogle()
      ..instances = [_instance('instance-1', DateTime.utc(2026, 3, 3, 9))];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    expect(fake.singleEventsCalls, 1);
    expect(fake.deletedEvents, ['instance-1']);
    expect(await db.select(db.outbox).get(), isEmpty);
    final cancelled = await (db.select(
      db.events,
    )..where((e) => e.recurringMasterId.equals('m1'))).getSingle();
    expect(cancelled.status, 'cancelled');
    expect(cancelled.deletedAt, isNull);
    expect(cancelled.remoteId, isNull);
    expect(cancelled.remoteEtag, isNull);
    expect(cancelled.dirty, isFalse);

    await engine.syncNow();
    expect(fake.deletedEvents.where((id) => id == 'instance-1'), hasLength(1));
    expect(fake.singleEventsCalls, 1);
  });

  test('pull relinks an echoed cancelled instance after delete', () async {
    await _cal(db);
    await _seedToken(db);
    await _seedMaster(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.deleteOccurrence(
      'm1',
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
    );
    final fake = FakeGoogle()
      ..instances = [_instance('instance-1', DateTime.utc(2026, 3, 3, 9))]
      ..events = [
        _cancelledInstance('instance-cancelled', DateTime.utc(2026, 3, 3, 9)),
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    final rows =
        await (db.select(db.events)..where(
              (e) => e.originalStart.equals(
                DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch,
              ),
            ))
            .get();
    expect(rows, hasLength(1));
    expect(rows.single.status, 'cancelled');
    expect(rows.single.remoteId, 'instance-cancelled');
    expect(rows.single.dirty, isFalse);
    expect(fake.deletedEvents, ['instance-1']);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('re-editing a deleted occurrence restores the same row', () async {
    await _cal(db);
    await _seedToken(db);
    await _seedMaster(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.deleteOccurrence(
      'm1',
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
    );
    final deleteFake = FakeGoogle()
      ..instances = [_instance('instance-1', DateTime.utc(2026, 3, 3, 9))];
    final deleteEngine = SyncEngine(db, clientFactory: () => deleteFake);
    await deleteEngine.syncNow();
    final before =
        await (db.select(db.events)..where(
              (e) => e.originalStart.equals(
                DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch,
              ),
            ))
            .getSingle();
    expect(before.status, 'cancelled');
    expect(before.remoteId, isNull);

    final exId = await repo.editOccurrence(
      'm1',
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      title: 'Restored',
    );
    expect(exId, before.id);
    final restored =
        await (db.select(db.events)..where(
              (e) => e.originalStart.equals(
                DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch,
              ),
            ))
            .get();
    expect(restored, hasLength(1));
    expect(restored.single.status, 'confirmed');
    expect(restored.single.deletedAt, isNull);
    expect(restored.single.dirty, isTrue);
    expect(restored.single.title, 'Restored');

    final fake = FakeGoogle()
      ..instances = [
        _cancelledInstance('instance-cancelled', DateTime.utc(2026, 3, 3, 9)),
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    expect(fake.singleEventsCalls, 1);
    expect(fake.patchedEventIds, ['instance-cancelled']);
    expect(fake.lastPatchBody?['status'], 'confirmed');
    expect(fake.lastPatchBody?['summary'], 'Restored');
    final pushed = await repo.getEvent(exId);
    expect(pushed!.status, 'confirmed');
    expect(pushed.remoteId, 'instance-cancelled');
    expect(pushed.dirty, isFalse);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('synced exception patches and deletes without lookup', () async {
    await _cal(db);
    await _seedToken(db);
    await _seedMaster(db);
    await _seedException(
      db,
      id: 'ex-edit',
      originalStart: DateTime.utc(2026, 3, 3, 9),
      remoteId: 'instance-edit',
    );
    await _seedException(
      db,
      id: 'ex-delete',
      originalStart: DateTime.utc(2026, 3, 4, 9),
      remoteId: 'instance-delete',
    );
    final repo = EventRepository(db, OccurrenceRepository(db));
    final fake = FakeGoogle();
    final engine = SyncEngine(db, clientFactory: () => fake);

    await repo.editOccurrence(
      'm1',
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      title: 'Edited',
    );
    await engine.syncNow();
    expect(fake.singleEventsCalls, 0);
    expect(fake.patchedEventIds, ['instance-edit']);
    expect(fake.lastPatchBody?['summary'], 'Edited');
    final edited = await repo.getEvent('ex-edit');
    expect(edited!.remoteId, 'instance-edit');
    expect(edited.dirty, isFalse);

    await repo.deleteOccurrence(
      'm1',
      DateTime.utc(2026, 3, 4, 9),
      scope: EditScope.single,
    );
    await engine.syncNow();
    expect(fake.singleEventsCalls, 0);
    expect(fake.deletedEvents, ['instance-delete']);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('exception patch retries once with a fresh etag after 412', () async {
    await _cal(db);
    await _seedToken(db);
    await _seedMaster(db);
    await _seedException(
      db,
      id: 'ex-edit',
      originalStart: DateTime.utc(2026, 3, 3, 9),
      remoteId: 'instance-edit',
    );
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      'm1',
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      title: 'Edited',
    );
    final fake = FakeGoogle()
      ..fail412Once = true
      ..instances = [_instance('instance-edit', DateTime.utc(2026, 3, 3, 9))];
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    expect(fake.etagHistory, ['ex-etag', 'ie-instance-edit']);
    expect(fake.patchedEventIds, ['instance-edit']);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(engine.status, SyncStatus.synced);
    final edited = await repo.getEvent('ex-edit');
    expect(edited!.remoteEtag, isNot('ex-etag'));
    expect(edited.dirty, isFalse);
  });

  test('edit all resetExceptions deletes remote exceptions', () async {
    await _cal(db);
    await _seedToken(db);
    await _seedMaster(db);
    await _seedException(
      db,
      id: 'ex-remote',
      originalStart: DateTime.utc(2026, 3, 3, 9),
      remoteId: 'instance-remote',
    );
    await _seedException(
      db,
      id: 'ex-local',
      originalStart: DateTime.utc(2026, 3, 4, 9),
    );
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      'm1',
      DateTime.utc(2026, 3, 2, 9),
      scope: EditScope.all,
      title: 'Renamed',
      resetExceptions: true,
    );

    final queued = await db.select(db.outbox).get();
    final deletes = queued
        .where((o) => o.entity == 'event' && o.op == 'delete')
        .map((o) => o.entityId);
    expect(deletes, ['ex-remote']);
    expect(
      queued.where((o) => o.entityId == 'm1').map((o) => o.op),
      contains('update'),
    );

    final fake = FakeGoogle();
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    expect(fake.singleEventsCalls, 0);
    expect(fake.deletedEvents, ['instance-remote']);
    final rows = await db.select(db.events).get();
    expect(
      rows
          .where((e) => e.id == 'ex-remote' || e.id == 'ex-local')
          .every((e) => e.deletedAt != null),
      isTrue,
    );
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test(
    'resetExceptions drops queued update for local-only exception',
    () async {
      await _cal(db);
      await _seedToken(db);
      await _seedMaster(db);
      await _seedException(
        db,
        id: 'ex-local',
        originalStart: DateTime.utc(2026, 3, 3, 9),
      );
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              id: 'op-local',
              entity: 'event',
              entityId: 'ex-local',
              op: 'update',
              createdAt: now,
            ),
          );
      final repo = EventRepository(db, OccurrenceRepository(db));
      await repo.editOccurrence(
        'm1',
        DateTime.utc(2026, 3, 2, 9),
        scope: EditScope.all,
        title: 'Renamed',
        resetExceptions: true,
      );

      final queued = await db.select(db.outbox).get();
      expect(queued.where((o) => o.entityId == 'ex-local'), isEmpty);
      final fake = FakeGoogle();
      final engine = SyncEngine(db, clientFactory: () => fake);
      await engine.syncNow();
      expect(fake.deletedEvents, isEmpty);
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );

  test('missing Google instance 404 does not stop other ops', () async {
    await _cal(db);
    await _seedToken(db);
    await _seedMaster(db);
    await _seedException(
      db,
      id: 'ex-gone',
      originalStart: DateTime.utc(2026, 3, 3, 9),
      remoteId: 'instance-gone',
      status: 'cancelled',
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'ok',
            calendarId: 'c1',
            title: const Value('New'),
            createdAt: now,
            updatedAt: now,
            dirty: const Value(true),
          ),
        );
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            id: 'op-gone',
            entity: 'event',
            entityId: 'ex-gone',
            op: 'delete',
            createdAt: now,
          ),
        );
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            id: 'op-ok',
            entity: 'event',
            entityId: 'ok',
            op: 'create',
            createdAt: now + 10,
          ),
        );

    final fake = _MissingInstanceDelete();
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    expect(fake.inserts, 1);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(engine.status, SyncStatus.synced);
  });

  test('missing instance on edit keeps the outbox op for retry', () async {
    await _cal(db);
    await _seedToken(db);
    await _seedMaster(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final exId = await repo.editOccurrence(
      'm1',
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      title: 'Special',
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'ok',
            calendarId: 'c1',
            title: const Value('New'),
            createdAt: now,
            updatedAt: now,
            dirty: const Value(true),
          ),
        );
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            id: 'op-ok',
            entity: 'event',
            entityId: 'ok',
            op: 'create',
            createdAt: now + 10,
          ),
        );

    final fake = FakeGoogle();
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();

    // The exception edit is retryable, not dropped; the later create still ran.
    expect(fake.singleEventsCalls, 1);
    expect(fake.inserts, 1);
    expect(engine.status, SyncStatus.error);
    expect(engine.errorKind, SyncErrorKind.server);
    final pending = await (db.select(
      db.outbox,
    )..where((o) => o.entityId.equals(exId))).getSingle();
    expect(pending.attempts, 1);
    expect(pending.nextTryAt, isNotNull);
    final ex = await repo.getEvent(exId);
    expect(ex!.remoteId, isNull);
    expect(ex.dirty, isTrue);
    final created = await (db.select(
      db.outbox,
    )..where((o) => o.entityId.equals('ok'))).get();
    expect(created, isEmpty);
  });

  test(
    'tasks: first pull with no cursor fetches once and stores a cursor',
    () async {
      final listId = await _seedTaskList(db);
      final fake = _TaskPullFake()..page('cursor-1');
      final engine = SyncEngine(db, clientFactory: () => fake);
      await engine.syncNow();
      expect(fake.pulledTaskLists, hasLength(1));
      expect(fake.updatedMins, [null]);
      expect(await _cursorOf(db, listId), 'cursor-1');
      expect(engine.status, SyncStatus.synced);
    },
  );

  test('tasks: no-change incremental makes exactly one request', () async {
    final listId = await _seedTaskList(db);
    await _seedCursor(db, listId, 'cursor-1');
    await _seedTaskRow(db, id: 't0', listId: listId, remoteId: 'g0');
    final fake = _TaskPullFake()..page('cursor-2');
    final engine = SyncEngine(db, clientFactory: () => fake);
    await engine.syncNow();
    expect(fake.pulledTaskLists, hasLength(1));
    expect(fake.updatedMins, ['cursor-1']);
    expect(await _cursorOf(db, listId), 'cursor-2');
    expect(engine.status, SyncStatus.synced);
  });

  for (final status in [400, 410]) {
    test(
      'tasks: invalid cursor $status triggers exactly one full retry',
      () async {
        final listId = await _seedTaskList(db);
        await _seedCursor(db, listId, 'cursor-1');
        await _seedTaskRow(db, id: 't0', listId: listId, remoteId: 'g0');
        final fake = _TaskPullFake()
          ..fail(status)
          ..page(
            'cursor-3',
            items: [
              {
                'id': 'g1',
                'etag': 'e1',
                'title': 'One',
                'status': 'needsAction',
              },
            ],
          );
        final engine = SyncEngine(db, clientFactory: () => fake);
        await engine.syncNow();
        expect(fake.pulledTaskLists, hasLength(2));
        expect(fake.updatedMins, ['cursor-1', null]);
        expect(await _cursorOf(db, listId), 'cursor-3');
        expect(engine.status, SyncStatus.synced);
        final rows = await (db.select(
          db.tasks,
        )..where((t) => t.remoteId.equals('g1'))).get();
        expect(rows, hasLength(1));
      },
    );
  }

  test(
    'tasks: local-empty list with cursor does at most one full fetch',
    () async {
      final listId = await _seedTaskList(db);
      await _seedCursor(db, listId, 'cursor-1');
      // No local task rows: the only recovery allowed is one bounded fetch.
      final fake = _TaskPullFake()
        ..page('cursor-2') // incremental: empty
        ..page('cursor-3'); // one bounded full fetch: empty
      final engine = SyncEngine(db, clientFactory: () => fake);
      await engine.syncNow();
      expect(fake.pulledTaskLists, hasLength(2));
      expect(fake.updatedMins, ['cursor-1', null]);
      expect(await _cursorOf(db, listId), 'cursor-3');
      expect(engine.status, SyncStatus.synced);
    },
  );

  test(
    'tasks: failed full retry keeps cursor and does not duplicate rows',
    () async {
      final listId = await _seedTaskList(db);
      await _seedCursor(db, listId, 'cursor-1');
      await _seedTaskRow(db, id: 't0', listId: listId, remoteId: 'g0');
      final fake = _TaskPullFake()
        ..fail(400)
        ..fail(500); // the single full retry also fails
      final engine = SyncEngine(db, clientFactory: () => fake);
      await engine.syncNow();
      expect(fake.pulledTaskLists, hasLength(2));
      expect(fake.updatedMins, ['cursor-1', null]);
      expect(await _cursorOf(db, listId), 'cursor-1');
      final rows = await (db.select(
        db.tasks,
      )..where((t) => t.remoteId.equals('g0'))).get();
      expect(rows, hasLength(1));
      expect(engine.status, SyncStatus.error);
    },
  );
}

class _RateLimitedOnce extends FakeGoogle {
  @override
  Future<Map<String, dynamic>> eventPatch(
    String calendarId,
    String eventId,
    Map<String, dynamic> body, {
    String? etag,
  }) async {
    throw GoogleApiException(429, 'slow down', retryAfterSec: 5);
  }
}

class _MissingInstanceDelete extends FakeGoogle {
  @override
  Future<void> eventDelete(String calendarId, String eventId) async {
    throw GoogleApiException(404, 'not found');
  }
}

class _TaskFetch {
  _TaskFetch.page(this.cursor, {this.items = const []}) : status = null;
  _TaskFetch.fail(this.status) : cursor = null, items = const [];

  final String? cursor;
  final List<Map<String, dynamic>> items;
  final int? status;
}

/// Scripted `tasksList` responses with full call tracing for cursor tests.
class _TaskPullFake extends FakeGoogle {
  final List<_TaskFetch> queue = [];
  final List<String?> updatedMins = [];

  void page(String cursor, {List<Map<String, dynamic>> items = const []}) =>
      queue.add(_TaskFetch.page(cursor, items: items));
  void fail(int status) => queue.add(_TaskFetch.fail(status));

  @override
  Future<TasksPage> tasksList(String id, {String? updatedMin}) async {
    pulledTaskLists.add(id);
    updatedMins.add(updatedMin);
    if (queue.isEmpty) {
      return TasksPage(items: [], nextUpdatedMin: 'cursor-fallback');
    }
    final next = queue.removeAt(0);
    if (next.status != null) throw GoogleApiException(next.status!, 'error');
    return TasksPage(items: List.of(next.items), nextUpdatedMin: next.cursor);
  }
}

Future<String> _seedTaskList(
  AppDatabase db, {
  String id = 'tl1',
  String remoteId = 'rtasklist1',
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.taskLists)
      .insert(
        TaskListsCompanion.insert(
          id: id,
          remoteId: Value(remoteId),
          name: 'Tasks',
          createdAt: now,
          updatedAt: now,
        ),
      );
  return id;
}

Future<void> _seedCursor(AppDatabase db, String listId, String value) async {
  await db
      .into(db.syncState)
      .insert(
        SyncStateCompanion.insert(
          key: 'tasks:$listId:updatedMin',
          value: Value(value),
        ),
      );
}

Future<void> _seedTaskRow(
  AppDatabase db, {
  required String id,
  required String listId,
  required String remoteId,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          id: id,
          listId: Value(listId),
          remoteId: Value(remoteId),
          title: const Value('Local'),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<String?> _cursorOf(AppDatabase db, String listId) async {
  final row = await (db.select(
    db.syncState,
  )..where((s) => s.key.equals('tasks:$listId:updatedMin'))).getSingleOrNull();
  return row?.value;
}
