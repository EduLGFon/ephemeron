// Shared-calendar dedupe: one deterministic reader per calendar, and a failed
// pull releases the reader claim so another account can retry next run.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/remote/google_api_client.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGoogle implements GoogleApiClient {
  List<Map<String, dynamic>> calendars = [];
  final Map<String, List<Map<String, dynamic>>> eventsByCal = {};
  final Map<String, List<Object>> failuresByCal = {};
  final List<String> pulledCalendars = [];

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
    final failures = failuresByCal[calendarId];
    if (failures != null && failures.isNotEmpty) {
      throw failures.removeAt(0);
    }
    pulledCalendars.add(calendarId);
    return CalendarPage(
      items: List.of(eventsByCal[calendarId] ?? const []),
      nextSyncToken: 'tok-$calendarId',
    );
  }

  @override
  Future<Map<String, dynamic>> eventInsert(
    String calendarId,
    Map<String, dynamic> body,
  ) async => {'id': 'remote-new', 'etag': 'e1'};

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
  Future<List<Map<String, dynamic>>> taskLists() async => const [];

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
  Future<TasksPage> tasksList(String id, {String? updatedMin}) async =>
      TasksPage(items: const [], nextUpdatedMin: 'now');

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
}

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _seedCalendar(
  AppDatabase db,
  String id,
  String remoteId, {
  String? account,
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
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Map<String, dynamic> _event(String id) => {
  'id': id,
  'etag': 'etag-$id',
  'summary': 'Shared event',
  'status': 'confirmed',
  'start': {'dateTime': '2026-03-03T12:00:00Z', 'timeZone': 'UTC'},
  'end': {'dateTime': '2026-03-03T13:00:00Z', 'timeZone': 'UTC'},
};

/// Calendar list where [shared] is readable. The first entry is malformed
/// (non-string summary) so discovery aborts before it can re-stamp the shared
/// row. That keeps the original owner stamp and forces the reader-claim path,
/// which is the cross-run scenario this case targets.
List<Map<String, dynamic>> _partialDiscoveryList() => [
  {'id': 'broken', 'summary': 42, 'accessRole': 'owner'},
  {'id': 'shared', 'summary': 'Shared', 'accessRole': 'reader'},
];

List<Map<String, dynamic>> _sharedList() => [
  {'id': 'shared', 'summary': 'Shared', 'accessRole': 'reader'},
];

Future<String?> _reader(AppDatabase db, String remoteId) async {
  final row = await (db.select(
    db.syncState,
  )..where((s) => s.key.equals('cal:reader:$remoteId'))).getSingleOrNull();
  return row?.value;
}

void main() {
  test('signed-in owner pulls; another signed-in account skips', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'shared', account: 'a@x');
    final fakeA = _FakeGoogle()
      ..calendars = _sharedList()
      ..eventsByCal['shared'] = [_event('g-shared')];
    final engineA = SyncEngine(
      db,
      clientFactory: () => fakeA,
      account: 'a@x',
      signedInAccounts: const ['a@x', 'b@x'],
    );

    await engineA.syncNow();

    expect(fakeA.pulledCalendars, ['shared']);
    final calendar = await (db.select(
      db.calendars,
    )..where((c) => c.id.equals('c1'))).getSingle();
    expect(calendar.googleAccount, 'a@x');

    final fakeB = _FakeGoogle()
      ..calendars = _sharedList()
      ..eventsByCal['shared'] = [_event('g-shared')];
    final engineB = SyncEngine(
      db,
      clientFactory: () => fakeB,
      account: 'b@x',
      signedInAccounts: const ['a@x', 'b@x'],
    );

    await engineB.syncNow();

    expect(fakeB.pulledCalendars, isEmpty);
    expect(await _reader(db, 'shared'), isNull);
  });

  test(
    'signed-out owner: one reader claims, others skip until it signs out',
    () async {
      final db = _db();
      addTearDown(db.close);
      await _seedCalendar(db, 'c1', 'shared', account: 'a@x');
      final fakeB = _FakeGoogle()..calendars = _partialDiscoveryList();
      final engineB = SyncEngine(
        db,
        clientFactory: () => fakeB,
        account: 'b@x',
        signedInAccounts: const ['b@x', 'c@x'],
      );

      await engineB.syncNow();

      expect(fakeB.pulledCalendars, ['shared']);
      expect(await _reader(db, 'shared'), 'b@x');

      // C is signed in alongside B, so the calendar already has its reader.
      final fakeC = _FakeGoogle()..calendars = _partialDiscoveryList();
      final engineC = SyncEngine(
        db,
        clientFactory: () => fakeC,
        account: 'c@x',
        signedInAccounts: const ['b@x', 'c@x'],
      );

      await engineC.syncNow();

      expect(fakeC.pulledCalendars, isEmpty);
      expect(await _reader(db, 'shared'), 'b@x');

      // B signed out: C may claim and pull the same calendar once.
      final fakeC2 = _FakeGoogle()..calendars = _partialDiscoveryList();
      final engineC2 = SyncEngine(
        db,
        clientFactory: () => fakeC2,
        account: 'c@x',
        signedInAccounts: const ['c@x'],
      );

      await engineC2.syncNow();

      expect(fakeC2.pulledCalendars, ['shared']);
      expect(await _reader(db, 'shared'), 'c@x');
    },
  );

  test(
    'failed claimed pull releases the reader for the next account',
    () async {
      final db = _db();
      addTearDown(db.close);
      await _seedCalendar(db, 'c1', 'shared', account: 'a@x');
      final fakeB = _FakeGoogle()..calendars = _partialDiscoveryList();
      fakeB.failOnce('shared', GoogleApiException(403, 'forbidden'));
      final engineB = SyncEngine(
        db,
        clientFactory: () => fakeB,
        account: 'b@x',
        signedInAccounts: const ['b@x', 'c@x'],
      );

      await engineB.syncNow();

      expect(fakeB.pulledCalendars, isEmpty);
      expect(await _reader(db, 'shared'), isNull);

      final fakeC = _FakeGoogle()..calendars = _partialDiscoveryList();
      final engineC = SyncEngine(
        db,
        clientFactory: () => fakeC,
        account: 'c@x',
        signedInAccounts: const ['c@x'],
      );

      await engineC.syncNow();

      expect(fakeC.pulledCalendars, ['shared']);
      expect(await _reader(db, 'shared'), 'c@x');
    },
  );

  test('freeBusyReader shared calendar is never pulled or claimed', () async {
    final db = _db();
    addTearDown(db.close);
    final fake = _FakeGoogle()
      ..calendars = [
        {
          'id': 'shared',
          'summary': 'Busy only',
          'accessRole': 'freeBusyReader',
        },
      ];
    final engine = SyncEngine(
      db,
      clientFactory: () => fake,
      account: 'b@x',
      signedInAccounts: const ['b@x', 'c@x'],
    );

    await engine.syncNow();

    expect(fake.pulledCalendars, isEmpty);
    expect(await _reader(db, 'shared'), isNull);
  });

  test('owner-signed-in case does not write a reader key', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db, 'c1', 'shared', account: 'a@x');
    final fake = _FakeGoogle()..calendars = _sharedList();
    final engine = SyncEngine(
      db,
      clientFactory: () => fake,
      account: 'a@x',
      signedInAccounts: const ['a@x', 'b@x'],
    );

    await engine.syncNow();

    expect(fake.pulledCalendars, ['shared']);
    expect(await _reader(db, 'shared'), isNull);
  });
}
