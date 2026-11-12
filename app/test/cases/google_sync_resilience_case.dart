// Resilience suite: stage isolation, Google error classification, shared and
// free/busy calendars, tombstone revival, recurrence selection, cache atomicity.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/mappers/google_mappers.dart';
import 'package:ephemeron/data/remote/google_api_client.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGoogle implements GoogleApiClient {
  List<Map<String, dynamic>> calendars = [];
  List<Map<String, dynamic>> taskListsResult = [];
  final Map<String, List<Map<String, dynamic>>> eventsByCal = {};
  final Map<String, List<Object>> failuresByCal = {};
  final Map<String, List<Object>> taskFailuresByList = {};
  final Map<String, String?> lastSyncTokenByCal = {};
  Object? calendarListError;
  Object? taskListsError;
  Object? insertError;
  final List<String> pulledCalendars = [];
  final List<String> pulledTaskLists = [];

  @override
  Future<List<Map<String, dynamic>>> calendarList() async {
    final error = calendarListError;
    if (error != null) throw error;
    return List.of(calendars);
  }

  @override
  Future<CalendarPage> eventsList(
    String calendarId, {
    String? syncToken,
    String? timeMin,
    String? timeMax,
    bool singleEvents = false,
    bool showDeleted = true,
  }) async {
    final failures = failuresByCal[calendarId];
    if (failures != null && failures.isNotEmpty) {
      throw failures.removeAt(0);
    }
    pulledCalendars.add(calendarId);
    lastSyncTokenByCal[calendarId] = syncToken;
    return CalendarPage(
      items: List.of(eventsByCal[calendarId] ?? const []),
      nextSyncToken: 'tok-$calendarId',
    );
  }

  @override
  Future<Map<String, dynamic>> eventInsert(
    String calendarId,
    Map<String, dynamic> body,
  ) async {
    final error = insertError;
    if (error != null) throw error;
    return {'id': 'remote-new', 'etag': 'e1'};
  }

  @override
  Future<Map<String, dynamic>> eventPatch(
    String calendarId,
    String eventId,
    Map<String, dynamic> body, {
    String? etag,
  }) async => {'etag': 'e2'};

  @override
  Future<Map<String, dynamic>> eventMove(
    String sourceCalendarId,
    String eventId,
    String destinationCalendarId,
  ) async => {'id': eventId, 'etag': 'e3'};

  @override
  Future<void> eventDelete(String calendarId, String eventId) async {}

  @override
  Future<List<Map<String, dynamic>>> taskLists() async {
    final error = taskListsError;
    if (error != null) throw error;
    return List.of(taskListsResult);
  }

  @override
  Future<Map<String, dynamic>> taskListCreate(String title) async => {
    'id': 'list-new',
    'etag': 'e1',
  };

  @override
  Future<Map<String, dynamic>> taskListPatch(
    String listId,
    String title,
  ) async => {'id': listId, 'etag': 'e2'};

  @override
  Future<void> taskListDelete(String listId) async {}

  @override
  Future<TasksPage> tasksList(String id, {String? updatedMin}) async {
    final failures = taskFailuresByList[id];
    if (failures != null && failures.isNotEmpty) {
      throw failures.removeAt(0);
    }
    pulledTaskLists.add(id);
    return TasksPage(items: const [], nextUpdatedMin: 'now');
  }

  @override
  Future<Map<String, dynamic>> taskInsert(
    String listId,
    Map<String, dynamic> body,
  ) async => {'id': 'task-new', 'etag': 'e1'};

  @override
  Future<Map<String, dynamic>> taskPatch(
    String listId,
    String taskId,
    Map<String, dynamic> body, {
    String? etag,
  }) async => {'etag': 'e2'};

  @override
  Future<Map<String, dynamic>> taskMove(
    String sourceTaskListId,
    String taskId,
    String destinationTaskListId,
  ) async => {'id': taskId, 'etag': 'e3'};

  @override
  Future<void> taskDelete(String listId, String taskId) async {}

  void failOnce(String remoteId, Object error) {
    failuresByCal.putIfAbsent(remoteId, () => []).add(error);
  }

  void failTaskOnce(String remoteListId, Object error) {
    taskFailuresByList.putIfAbsent(remoteListId, () => []).add(error);
  }
}

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _seedCalendar(
  AppDatabase db,
  String id,
  String remoteId, {
  String? account,
  bool readOnly = false,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: id,
          remoteId: Value(remoteId),
          name: 'Calendar $id',
          source: const Value('google'),
          googleAccount: Value(account),
          readOnly: Value(readOnly),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _seedTaskList(
  AppDatabase db,
  String id,
  String remoteId, {
  String? account,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.taskLists)
      .insert(
        TaskListsCompanion.insert(
          id: id,
          remoteId: Value(remoteId),
          name: 'List $id',
          googleAccount: Value(account),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _seedOutboxEvent(
  AppDatabase db, {
  required String eventId,
  required String calendarId,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: eventId,
          calendarId: calendarId,
          title: const Value('Local draft'),
          createdAt: now,
          updatedAt: now,
          dirty: const Value(true),
        ),
      );
  await db
      .into(db.outbox)
      .insert(
        OutboxCompanion.insert(
          id: 'op-$eventId',
          entity: 'event',
          entityId: eventId,
          op: 'create',
          createdAt: now,
        ),
      );
}

Future<void> _seedToken(AppDatabase db, String calendarId, String value) async {
  await db
      .into(db.syncState)
      .insert(
        SyncStateCompanion.insert(
          key: 'cal:v2:$calendarId:token',
          value: Value(value),
          lastSyncAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
        ),
      );
}

Map<String, dynamic> _event(String id, {String summary = 'Remote'}) => {
  'id': id,
  'etag': 'etag-$id',
  'summary': summary,
  'status': 'confirmed',
  'start': {'dateTime': '2026-03-03T12:00:00Z', 'timeZone': 'UTC'},
  'end': {'dateTime': '2026-03-03T13:00:00Z', 'timeZone': 'UTC'},
};

String _googleError(String reason) => jsonEncode({
  'error': {
    'errors': [
      {'reason': reason},
    ],
    'code': 403,
  },
});

void main() {
  test(
    'push exception does not stop pull; failed push reports error',
    () async {
      final db = _db();
      addTearDown(db.close);
      await _seedCalendar(db, 'c1', 'r1');
      await _seedOutboxEvent(db, eventId: 'e1', calendarId: 'c1');
      final fake = _FakeGoogle()
        ..calendars = [
          {'id': 'r1', 'summary': 'Calendar', 'accessRole': 'owner'},
        ]
        ..eventsByCal['r1'] = [_event('g1')]
        ..insertError = const SocketException('offline');
      final engine = SyncEngine(db, clientFactory: () => fake);

      await engine.syncNow();

      expect(fake.pulledCalendars, contains('r1'));
      final merged = await (db.select(
        db.events,
      )..where((e) => e.remoteId.equals('g1'))).get();
      expect(merged, hasLength(1));
      expect(engine.authFailure, isFalse);
      expect(engine.errorKind, SyncErrorKind.network);
      expect(engine.status, SyncStatus.error);
      final queued = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals('op-e1'))).getSingle();
      expect(queued.attempts, 1);
      expect(queued.nextTryAt, isNotNull);

      // A later successful run clears the failure state.
      fake.insertError = null;
      await engine.retryFailed('op-e1');
      await engine.syncNow();
      expect(await db.select(db.outbox).get(), isEmpty);
      expect(engine.authFailure, isFalse);
      expect(engine.errorKind, SyncErrorKind.none);
      expect(engine.status, SyncStatus.synced);
      expect(engine.lastError, isNull);
    },
  );

  test('push Error does not stop pull; reports unknown failure', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'r1');
    await _seedOutboxEvent(db, eventId: 'e1', calendarId: 'c1');
    final fake = _FakeGoogle()
      ..calendars = [
        {'id': 'r1', 'summary': 'Calendar', 'accessRole': 'owner'},
      ]
      ..eventsByCal['r1'] = [_event('g1')]
      ..insertError = StateError('boom');
    final engine = SyncEngine(db, clientFactory: () => fake);

    await engine.syncNow();

    expect(fake.pulledCalendars, contains('r1'));
    final merged = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('g1'))).get();
    expect(merged, hasLength(1));
    expect(engine.authFailure, isFalse);
    expect(engine.errorKind, SyncErrorKind.unknown);
    expect(engine.status, SyncStatus.error);
  });

  test('calendar discovery failure still pulls known calendars', () async {
    for (final entry in <(Object Function(), SyncErrorKind)>[
      (() => GoogleApiException(500, 'boom'), SyncErrorKind.server),
      (() => const SocketException('offline'), SyncErrorKind.network),
    ]) {
      final db = _db();
      addTearDown(db.close);
      await _seedCalendar(db, 'c1', 'r1');
      final fake = _FakeGoogle()
        ..calendarListError = entry.$1()
        ..eventsByCal['r1'] = [_event('g1')];
      final engine = SyncEngine(db, clientFactory: () => fake);

      await engine.syncNow();

      expect(fake.pulledCalendars, contains('r1'));
      final merged = await (db.select(
        db.events,
      )..where((e) => e.remoteId.equals('g1'))).get();
      expect(merged, hasLength(1));
      expect(engine.authFailure, isFalse);
      expect(engine.errorKind, entry.$2);
      expect(engine.status, SyncStatus.error);
    }
  });

  test('discovery sets reset each run so stale ids do not filter', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'r1');
    await _seedCalendar(db, 'c2', 'r2');
    final fake = _FakeGoogle()
      ..calendars = [
        {'id': 'r1', 'summary': 'One', 'accessRole': 'owner'},
      ]
      ..eventsByCal['r1'] = [_event('g1')]
      ..eventsByCal['r2'] = [_event('g2')];
    final engine = SyncEngine(db, clientFactory: () => fake, account: 'a@x');

    await engine.syncNow();
    // The first run discovered only r1, so r2 is filtered.
    expect(fake.pulledCalendars, ['r1']);

    // A failed discovery must clear the r1-only set rather than reuse it.
    fake.calendarListError = const SocketException('offline');
    await engine.syncNow();
    expect(fake.pulledCalendars.where((id) => id == 'r2'), hasLength(1));

    // A later successful run discovers both and pulls both.
    fake.calendarListError = null;
    fake.calendars = [
      {'id': 'r1', 'summary': 'One', 'accessRole': 'owner'},
      {'id': 'r2', 'summary': 'Two', 'accessRole': 'owner'},
    ];
    await engine.syncNow();
    expect(fake.pulledCalendars.where((id) => id == 'r2'), hasLength(2));
    expect(engine.status, SyncStatus.synced);
  });

  test('per-calendar forbidden 403 skips only that calendar', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'r-forbidden', account: 'a@x');
    await _seedCalendar(db, 'c2', 'r-ok', account: 'a@x');
    final fake = _FakeGoogle()
      ..calendars = [
        {'id': 'r-forbidden', 'summary': 'Busy', 'accessRole': 'reader'},
        {'id': 'r-ok', 'summary': 'Ok', 'accessRole': 'owner'},
      ]
      ..eventsByCal['r-ok'] = [_event('g-ok')]
      ..failOnce(
        'r-forbidden',
        GoogleApiException(403, _googleError('forbidden')),
      );
    final engine = SyncEngine(db, clientFactory: () => fake, account: 'a@x');

    await engine.syncNow();

    expect(fake.pulledCalendars, ['r-ok']);
    final merged = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('g-ok'))).get();
    expect(merged, hasLength(1));
    expect(engine.authFailure, isFalse);
    expect(engine.errorKind, isNot(SyncErrorKind.auth));
    expect(engine.status, SyncStatus.synced);
    final meta = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals('cal:c1:meta'))).getSingle();
    expect(meta.lastError, 'forbidden');
  });

  test('per-calendar insufficientPermissions is an auth failure', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'r-bad', account: 'a@x');
    await _seedCalendar(db, 'c2', 'r-ok', account: 'a@x');
    final fake = _FakeGoogle()
      ..calendars = [
        {'id': 'r-bad', 'summary': 'Bad', 'accessRole': 'owner'},
        {'id': 'r-ok', 'summary': 'Ok', 'accessRole': 'owner'},
      ]
      ..eventsByCal['r-ok'] = [_event('g-ok')]
      ..failOnce(
        'r-bad',
        GoogleApiException(403, _googleError('insufficientPermissions')),
      );
    final engine = SyncEngine(db, clientFactory: () => fake, account: 'a@x');

    await engine.syncNow();

    expect(fake.pulledCalendars, ['r-ok']);
    expect(engine.authFailure, isTrue);
    expect(engine.errorKind, SyncErrorKind.auth);
    expect(engine.status, SyncStatus.error);
  });

  test('rate-limit 429 and quota 403 are not auth failures', () async {
    for (final error in [
      GoogleApiException(429, 'slow down', retryAfterSec: 5),
      GoogleApiException(403, _googleError('quotaExceeded')),
      GoogleApiException(403, _googleError('dailyLimitExceeded')),
      GoogleApiException(403, _googleError('calendarUsageLimitsExceeded')),
    ]) {
      final db = _db();
      addTearDown(db.close);
      await _seedCalendar(db, 'c1', 'r1', account: 'a@x');
      final fake = _FakeGoogle()
        ..calendars = [
          {'id': 'r1', 'summary': 'Calendar', 'accessRole': 'owner'},
        ]
        ..failOnce('r1', error);
      final engine = SyncEngine(db, clientFactory: () => fake, account: 'a@x');

      await engine.syncNow();

      expect(engine.authFailure, isFalse);
      expect(engine.errorKind, SyncErrorKind.rateLimited);
      expect(engine.status, SyncStatus.error);
    }
  });

  test('task-list 404/forbidden is recorded without auth failure', () async {
    for (final (error, label) in <(GoogleApiException, String)>[
      (GoogleApiException(404, 'not found'), 'Google 404'),
      (GoogleApiException(403, _googleError('forbidden')), 'forbidden'),
    ]) {
      final db = _db();
      addTearDown(db.close);
      await _seedTaskList(db, 'l1', 'rl1', account: 'a@x');
      final fake = _FakeGoogle()
        ..taskListsResult = [
          {'id': 'rl1', 'title': 'List'},
        ]
        ..failTaskOnce('rl1', error);
      final engine = SyncEngine(db, clientFactory: () => fake, account: 'a@x');

      await engine.syncNow();

      expect(engine.authFailure, isFalse);
      expect(engine.errorKind, SyncErrorKind.none);
      expect(engine.status, SyncStatus.synced);
      final meta = await (db.select(
        db.syncState,
      )..where((s) => s.key.equals('tasks:l1:meta'))).getSingle();
      expect(meta.lastError, label);
    }
  });

  test('task-list discovery 404/forbidden stays list-only', () async {
    for (final (error, label) in <(GoogleApiException, String)>[
      (GoogleApiException(404, 'not found'), 'Google 404'),
      (GoogleApiException(403, _googleError('forbidden')), 'Google 403'),
    ]) {
      final db = _db();
      addTearDown(db.close);
      await _seedTaskList(db, 'l1', 'rl1', account: 'a@x');
      final fake = _FakeGoogle()..taskListsError = error;
      final engine = SyncEngine(db, clientFactory: () => fake, account: 'a@x');

      await engine.syncNow();

      expect(engine.authFailure, isFalse);
      expect(engine.errorKind, SyncErrorKind.none);
      expect(engine.status, SyncStatus.synced);
      final meta = await (db.select(
        db.syncState,
      )..where((s) => s.key.equals('tasks:meta'))).getSingle();
      expect(meta.lastError, label);
    }
  });

  test('task-list discovery auth/rate/server stay global failures', () async {
    for (final (error, kind, auth)
        in <(GoogleApiException, SyncErrorKind, bool)>[
          (
            GoogleApiException(403, _googleError('insufficientPermissions')),
            SyncErrorKind.auth,
            true,
          ),
          (
            GoogleApiException(429, 'slow down'),
            SyncErrorKind.rateLimited,
            false,
          ),
          (GoogleApiException(500, 'boom'), SyncErrorKind.server, false),
          (
            GoogleApiException(400, 'bad request'),
            SyncErrorKind.unknown,
            false,
          ),
        ]) {
      final db = _db();
      addTearDown(db.close);
      await _seedTaskList(db, 'l1', 'rl1', account: 'a@x');
      final fake = _FakeGoogle()..taskListsError = error;
      final engine = SyncEngine(db, clientFactory: () => fake, account: 'a@x');

      await engine.syncNow();

      expect(engine.authFailure, auth);
      expect(engine.errorKind, kind);
      expect(engine.status, SyncStatus.error);
    }
  });

  test('freeBusyReader calendar is read-only and not pulled', () async {
    final db = _db();
    addTearDown(db.close);
    final fake = _FakeGoogle()
      ..calendars = [
        {
          'id': 'r-busy',
          'summary': 'Busy only',
          'accessRole': 'freeBusyReader',
        },
        {'id': 'r-ok', 'summary': 'Ok', 'accessRole': 'owner'},
      ];
    final engine = SyncEngine(db, clientFactory: () => fake, account: 'a@x');

    await engine.syncNow();

    expect(fake.pulledCalendars, ['r-ok']);
    final busy = await (db.select(
      db.calendars,
    )..where((c) => c.remoteId.equals('r-busy'))).getSingle();
    expect(busy.readOnly, isTrue);
    expect(engine.authFailure, isFalse);
    expect(engine.errorKind, SyncErrorKind.none);
    expect(engine.status, SyncStatus.synced);
  });

  test('B skips the A-owned shared calendar', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'shared', account: 'a@x');
    final fake = _FakeGoogle()
      ..calendars = [
        {'id': 'shared', 'summary': 'Shared', 'accessRole': 'reader'},
      ]
      ..eventsByCal['shared'] = [_event('g-shared')];
    final engine = SyncEngine(
      db,
      clientFactory: () => fake,
      account: 'b@x',
      signedInAccounts: const ['a@x', 'b@x'],
    );

    await engine.syncNow();

    // The owner account pulls the shared calendar; B must not duplicate it.
    expect(fake.pulledCalendars, isEmpty);
    final calendar = await (db.select(
      db.calendars,
    )..where((c) => c.id.equals('c1'))).getSingle();
    expect(calendar.googleAccount, 'a@x');
    final merged = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('g-shared'))).get();
    expect(merged, isEmpty);
    expect(engine.status, SyncStatus.synced);
  });

  test('full resync keeps occurrence rows until the rebuild', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'r1');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'old',
            calendarId: 'c1',
            remoteId: const Value('g-old'),
            title: const Value('Old'),
            startUtc: Value(
              DateTime.utc(2026, 3, 3, 12).millisecondsSinceEpoch,
            ),
            endUtc: Value(DateTime.utc(2026, 3, 3, 13).millisecondsSinceEpoch),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.occurrenceCache)
        .insert(
          OccurrenceCacheCompanion.insert(
            id: 'oc1',
            eventId: 'old',
            startUtc: DateTime.utc(2026, 3, 3, 12).millisecondsSinceEpoch,
            endUtc: DateTime.utc(2026, 3, 3, 13).millisecondsSinceEpoch,
            dayKey: '2026-03-03',
          ),
        );
    final fake = _FakeGoogle()
      ..calendars = [
        {'id': 'r1', 'summary': 'Calendar', 'accessRole': 'owner'},
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);

    await engine.syncNow();

    final oldEvent = await (db.select(
      db.events,
    )..where((e) => e.id.equals('old'))).getSingleOrNull();
    expect(oldEvent, isNull);
    expect(await db.select(db.occurrenceCache).get(), hasLength(1));

    await OccurrenceRepository(db).rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 8),
    );
    expect(await db.select(db.occurrenceCache).get(), isEmpty);
  });

  test('410 followed by a failing resync does not escape the pull', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'r1');
    await _seedCalendar(db, 'c2', 'r2');
    await _seedToken(db, 'c1', 'stale-token');
    final fake = _FakeGoogle()
      ..calendars = [
        {'id': 'r1', 'summary': 'One', 'accessRole': 'owner'},
        {'id': 'r2', 'summary': 'Two', 'accessRole': 'owner'},
      ]
      ..eventsByCal['r2'] = [_event('g2')]
      ..failOnce('r1', GoogleApiException(410, 'gone'))
      ..failOnce('r1', GoogleApiException(500, 'boom'));
    final engine = SyncEngine(db, clientFactory: () => fake);

    await engine.syncNow();

    final merged = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('g2'))).get();
    expect(merged, hasLength(1));
    expect(engine.authFailure, isFalse);
    expect(engine.errorKind, SyncErrorKind.server);
    expect(engine.status, SyncStatus.error);
    // The stale token is dropped before the failed resync, so a repeated 410
    // cannot survive a second failure.
    final token = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals('cal:v2:c1:token'))).getSingleOrNull();
    expect(token, isNull);

    // Next run has no sync token, so it performs a full resync.
    await engine.syncNow();
    expect(fake.lastSyncTokenByCal['r1'], isNull);
    final fresh = await (db.select(
      db.syncState,
    )..where((s) => s.key.equals('cal:v2:c1:token'))).getSingle();
    expect(fresh.value, 'tok-r1');
  });

  test('malformed item throwing Error is skipped, later items merge', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'r1');
    final fake = _FakeGoogle()
      ..calendars = [
        {'id': 'r1', 'summary': 'Calendar', 'accessRole': 'owner'},
      ]
      ..eventsByCal['r1'] = [
        {'id': 'bad', 'status': 'confirmed', 'start': 'not-a-map', 'end': {}},
        _event('g-good'),
      ];
    final engine = SyncEngine(db, clientFactory: () => fake);

    await engine.syncNow();

    final rows = await db.select(db.events).get();
    expect(rows.where((e) => e.remoteId == 'g-good'), hasLength(1));
    expect(rows.where((e) => e.remoteId == 'bad'), isEmpty);
    expect(engine.status, SyncStatus.synced);
    expect(engine.errorKind, SyncErrorKind.none);
  });

  test('confirmed event revives a cancelled tombstone', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'r1');
    final fake = _FakeGoogle()
      ..calendars = [
        {'id': 'r1', 'summary': 'Calendar', 'accessRole': 'owner'},
      ]
      ..eventsByCal['r1'] = [_event('g1')];
    final engine = SyncEngine(db, clientFactory: () => fake);

    await engine.syncNow();
    fake.eventsByCal['r1'] = [
      {
        'id': 'g1',
        'etag': 'cancelled',
        'summary': 'Cancelled',
        'status': 'cancelled',
      },
    ];
    await engine.syncNow();
    var row = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('g1'))).getSingle();
    expect(row.deletedAt, isNotNull);

    fake.eventsByCal['r1'] = [_event('g1')];
    await engine.syncNow();

    row = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('g1'))).getSingle();
    expect(row.deletedAt, isNull);
    expect(row.status, 'confirmed');
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 8),
    );
    expect(await repo.occurrencesForDay('2026-03-03'), isNotEmpty);
  });

  test('recurrence selects RRULE even when another line is first', () {
    final mapped = eventFromGoogle(
      {
        'id': 'g1',
        'status': 'confirmed',
        'start': {'dateTime': '2026-03-03T12:00:00Z'},
        'end': {'dateTime': '2026-03-03T13:00:00Z'},
        'recurrence': [
          'EXDATE;TZID=UTC:20260310T120000Z',
          'RRULE:FREQ=WEEKLY;COUNT=2',
        ],
      },
      'c1',
      'local1',
    );
    expect(mapped.companion.rrule.value, 'FREQ=WEEKLY;COUNT=2');
  });

  test('originalStartTime parses dateTime, date, and malformed input', () {
    expect(
      originalStartMsFromGoogle({
        'originalStartTime': {'dateTime': '2026-03-03T09:00:00Z'},
      }),
      DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch,
    );
    expect(
      originalStartMsFromGoogle({
        'originalStartTime': {'date': '2026-03-03'},
      }),
      DateTime.utc(2026, 3, 3).millisecondsSinceEpoch,
    );
    expect(
      originalStartMsFromGoogle({
        'originalStartTime': {'dateTime': 'not-a-date'},
      }),
      isNull,
    );
    expect(
      originalStartMsFromGoogle({
        'originalStartTime': {'date': '2026-02-31'},
      }),
      isNull,
    );
    expect(originalStartMsFromGoogle({'originalStartTime': 'bad'}), isNull);
    expect(originalStartMsFromGoogle({}), isNull);
  });
}
