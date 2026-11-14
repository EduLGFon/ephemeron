// Sync reliability fixes: per-account tokens, HTTP timeouts, duplicate task
// remote ids.
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/remote/google_api_client.dart';
import 'package:ephemeron/features/auth/application/auth_providers.dart';
import 'package:ephemeron/features/auth/data/google_auth.dart';
import 'package:ephemeron/features/auth/data/microsoft_auth.dart';
import 'package:ephemeron/features/sync/application/sync_providers.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

class _FakeGoogleAuth extends GoogleAuth {
  _FakeGoogleAuth({required List<String> accounts, required this.tokenFor})
    : accountList = [...accounts];

  final List<String> accountList;
  final Map<String, String?> tokenFor;
  final List<String> tokenRequests = [];
  int restoreCalls = 0;

  @override
  List<String> get accounts => List.unmodifiable(accountList);

  @override
  Future<String?> accessToken() async {
    throw StateError('global accessToken must not be used');
  }

  @override
  Future<String?> accessTokenFor(String account) async {
    tokenRequests.add(account);
    return tokenFor[account];
  }

  @override
  Future<String?> restore() async {
    restoreCalls++;
    return null;
  }
}

class _FakeMicrosoftAuth extends MicrosoftAuth {
  @override
  List<String> get accounts => const [];

  @override
  Future<String?> restore() async => null;

  @override
  Future<void> setActiveAccount(String email) async {}

  @override
  Future<String?> accessTokenFor(String account) async => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'sync uses accessTokenFor per account, not global accessToken',
    () async {
      final db = _db();
      final auth = _FakeGoogleAuth(
        accounts: const ['a@example.com', 'b@example.com'],
        tokenFor: const {
          'a@example.com': 'token-a',
          'b@example.com': 'token-b',
        },
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          googleAuthProvider.overrideWithValue(auth),
          microsoftAuthProvider.overrideWithValue(_FakeMicrosoftAuth()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
      await http.runWithClient(
        () => container.read(syncStatusProvider.notifier).syncNow(),
        () => MockClient((request) async {
          return http.Response('{"items":[]}', 200);
        }),
      );
      // Reaching here means no global accessToken() was invoked.
      expect(
        auth.tokenRequests,
        containsAll(['a@example.com', 'b@example.com']),
      );
      expect(container.read(syncStatusProvider), isNot(SyncStatus.error));
      expect(auth.restoreCalls, 0);
    },
  );

  test('sync restores stored accounts before reporting offline', () async {
    final db = _db();
    addTearDown(db.close);
    final auth = _FakeGoogleAuth(accounts: const [], tokenFor: const {});
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        googleAuthProvider.overrideWithValue(auth),
        microsoftAuthProvider.overrideWithValue(_FakeMicrosoftAuth()),
      ],
    );
    addTearDown(container.dispose);
    await http.runWithClient(
      () => container.read(syncStatusProvider.notifier).syncNow(),
      () => MockClient((request) async => http.Response('{"items":[]}', 200)),
    );
    expect(auth.restoreCalls, 1);
    expect(container.read(syncStatusProvider), SyncStatus.offline);
  });

  test('HttpGoogleApiClient times out with short injected timeout', () async {
    final client = HttpGoogleApiClient(
      accessToken: () async => 'token',
      httpClient: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('{"items":[]}', 200);
      }),
      requestTimeout: const Duration(milliseconds: 10),
    );
    await expectLater(client.calendarList(), throwsA(isA<TimeoutException>()));
  });

  test('duplicate task remote ids do not throw during pull', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.taskLists)
        .insert(
          TaskListsCompanion.insert(
            id: 'list1',
            remoteId: const Value('remoteList'),
            name: 'List',
            createdAt: now,
            updatedAt: now,
            googleAccount: const Value('a@example.com'),
          ),
        );
    // Pre-existing duplicate rows for the same remote task id.
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: 't1',
            listId: const Value('list1'),
            title: const Value('Task'),
            createdAt: now,
            updatedAt: now,
            remoteId: const Value('remoteTask'),
            googleAccount: const Value('a@example.com'),
          ),
        );
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: 't2',
            listId: const Value('list1'),
            title: const Value('Task'),
            createdAt: now,
            updatedAt: now,
            remoteId: const Value('remoteTask'),
            googleAccount: const Value(null),
          ),
        );

    final engine = SyncEngine(
      db,
      clientFactory: () => HttpGoogleApiClient(
        accessToken: () async => 'token',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/tasklists')) {
            return http.Response(
              '{"items":[{"id":"remoteList","title":"List"}]}',
              200,
            );
          }
          if (request.url.path.contains('/tasks')) {
            return http.Response(
              '{"items":[{"id":"remoteTask","title":"Task","status":"needsAction"}]}',
              200,
            );
          }
          return http.Response('{"items":[]}', 200);
        }),
      ),
      account: 'a@example.com',
      signedInAccounts: const ['a@example.com'],
    );
    await engine.syncNow();
    expect(engine.status, isNot(SyncStatus.error));
  });
}
