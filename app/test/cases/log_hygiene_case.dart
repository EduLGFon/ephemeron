import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/remote/google_api_client.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/test_fixtures.dart';

class _LogCapture {
  final List<String> lines = [];
  DebugPrintCallback? _old;

  void start() {
    _old = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
  }

  void stop() {
    final old = _old;
    if (old != null) debugPrint = old;
  }
}

class _FakeGoogle implements GoogleApiClient {
  _FakeGoogle({
    this.taskListsError,
    this.eventsListError,
    this.calendarListItems = const [],
  });

  final Object? taskListsError;
  final Object? eventsListError;
  final List<Map<String, dynamic>> calendarListItems;

  @override
  Future<List<Map<String, dynamic>>> calendarList() async => calendarListItems;

  @override
  Future<List<Map<String, dynamic>>> taskLists() async {
    if (taskListsError != null) throw taskListsError!;
    return const [];
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
    if (eventsListError != null) throw eventsListError!;
    return CalendarPage(items: const [], nextSyncToken: 'tok');
  }

  @override
  Future<Map<String, dynamic>> eventInsert(
    String calendarId,
    Map<String, dynamic> body,
  ) async => const {};

  @override
  Future<Map<String, dynamic>> eventPatch(
    String calendarId,
    String eventId,
    Map<String, dynamic> body, {
    String? etag,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> eventMove(
    String sourceCalendarId,
    String eventId,
    String destinationCalendarId,
  ) async => const {};

  @override
  Future<void> eventDelete(String calendarId, String eventId) async {}

  @override
  Future<Map<String, dynamic>> taskListCreate(String title) async => const {};

  @override
  Future<Map<String, dynamic>> taskListPatch(
    String listId,
    String title,
  ) async => const {};

  @override
  Future<void> taskListDelete(String listId) async {}

  @override
  Future<TasksPage> tasksList(String id, {String? updatedMin}) async =>
      TasksPage(items: const [], nextUpdatedMin: null);

  @override
  Future<Map<String, dynamic>> taskInsert(
    String l,
    Map<String, dynamic> b,
  ) async => const {};

  @override
  Future<Map<String, dynamic>> taskPatch(
    String l,
    String t,
    Map<String, dynamic> b, {
    String? etag,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> taskMove(
    String sourceTaskListId,
    String taskId,
    String destinationTaskListId,
  ) async => const {};

  @override
  Future<void> taskDelete(String l, String t) async {}
}

Future<void> _seedCalendar(AppDatabase db) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: 'c1',
          remoteId: const Value('remote-cal'),
          name: 'Test',
          source: const Value('google'),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

void main() {
  testWidgets('go_router StatefulShellRoute navigation emits no matches log', (
    tester,
  ) async {
    final capture = _LogCapture()..start();
    addTearDown(capture.stop);

    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                NavigationDestination(icon: Icon(Icons.search), label: 'B'),
              ],
            ),
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/a',
                  builder: (context, state) => const Text('A'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/b',
                  builder: (context, state) => const Text('B'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/b');
    await tester.pumpAndSettle();
    router.go('/a');
    await tester.pumpAndSettle();
    router.go('/b');
    await tester.pumpAndSettle();

    expect(
      capture.lines.where((l) => l.contains('matches=[ShellRouteMatch')),
      isEmpty,
    );
  });

  group('sync log clarity', () {
    late AppDatabase db;

    setUpAll(() => db = newTestDb());
    setUp(() => resetTestDb(db));
    tearDownAll(() => db.close());

    test('401 discovery logs status and kind=auth', () async {
      final capture = _LogCapture()..start();
      addTearDown(capture.stop);

      final engine = SyncEngine(
        db,
        clientFactory: () => _FakeGoogle(
          taskListsError: GoogleApiException(401, 'unauthorized'),
        ),
      );
      await engine.syncNow();

      final joined = capture.lines.join('\n');
      expect(joined, contains('status=401'));
      expect(joined, contains('kind=auth'));
    });

    test('410 calendar pull logs status and kind=not_found', () async {
      await _seedCalendar(db);
      final capture = _LogCapture()..start();
      addTearDown(capture.stop);

      final engine = SyncEngine(
        db,
        clientFactory: () =>
            _FakeGoogle(eventsListError: GoogleApiException(410, 'gone')),
      );
      // eventsListError is thrown on every call; full resync also calls
      // eventsList, so the resync retry will also fail - that's fine, we
      // only need the 410 failure log.
      await engine.syncNow();

      final joined = capture.lines.join('\n');
      expect(joined, contains('status=410'));
      expect(joined, contains('kind=not_found'));
    });

    test('legacy calendar repair log does not contain local id', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.calendars)
          .insert(
            CalendarsCompanion.insert(
              id: 'local-secret-id',
              name: 'Legacy',
              source: const Value('google'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final capture = _LogCapture()..start();
      addTearDown(capture.stop);

      final engine = SyncEngine(
        db,
        clientFactory: () => _FakeGoogle(
          calendarListItems: const [
            {'id': 'remote-1', 'summary': 'Legacy'},
          ],
        ),
      );
      await engine.syncNow();

      final row = await (db.select(
        db.calendars,
      )..where((t) => t.id.equals('local-secret-id'))).getSingle();
      expect(row.remoteId, 'remote-1');
      expect(capture.lines.join('\n'), isNot(contains('local-secret-id')));
    });
  });
}
