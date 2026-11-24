// Intermittent-sync regression: auth/rate/network classification, outbox
// draining, and the stale-401 silent-refresh path that used to leave queued
// changes stranded behind backoff after reporting a clean success.
import 'package:drift/drift.dart' show Value;
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/remote/google_api_client.dart';
import 'package:ephemeron/features/auth/data/google_auth.dart';
import 'package:ephemeron/features/sync/data/google_account_sync.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'sync_engine_case.dart' show FakeGoogle;
import '../support/test_fixtures.dart';

Future<void> _seedQueuedEvent(AppDatabase db) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: 'c1',
          remoteId: const Value('r1'),
          name: 'Calendar',
          source: const Value('google'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: 'e1',
          calendarId: 'c1',
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
          id: 'op-e1',
          entity: 'event',
          entityId: 'e1',
          op: 'create',
          createdAt: now,
        ),
      );
}

/// Fails the first event insert, then succeeds, so the same engine can drain
/// the row on a following run.
class _FlakyPush extends FakeGoogle {
  _FlakyPush(this.firstError);

  final Object firstError;
  int _calls = 0;

  @override
  Future<Map<String, dynamic>> eventInsert(
    String calendarId,
    Map<String, dynamic> body,
  ) async {
    if (_calls++ == 0) throw firstError;
    return {'id': 'remote-ok', 'etag': 'e1'};
  }
}

class _RecoveringAuth extends GoogleAuth {
  _RecoveringAuth(this.account, String token) : _tokens = {account: token};

  final String account;
  final Map<String, String> _tokens;
  final Map<String, int> acquisitions = {};
  final Map<String, int> invalidations = {};
  final List<String> reconnect = [];

  @override
  List<String> get accounts => [account];

  @override
  List<String> get accountsNeedingReconnect => List.unmodifiable(reconnect);

  @override
  Future<String?> accessToken() async =>
      throw StateError('global accessToken must not be used');

  @override
  Future<String?> accessTokenFor(String email) async {
    acquisitions[email] = (acquisitions[email] ?? 0) + 1;
    return _tokens[email];
  }

  @override
  Future<void> invalidateAccessTokenFor(String email) async {
    invalidations[email] = (invalidations[email] ?? 0) + 1;
    _tokens[email] = 'fresh-$email';
  }

  @override
  Future<String?> restore() async => null;
}

void main() {
  late AppDatabase db;
  setUpAll(() => db = newTestDb());
  setUp(() => resetTestDb(db));
  tearDownAll(() => db.close());
  test(
    'syncNow classifies auth, rate-limited and network push failures',
    () async {
      final cases = <(Object, SyncErrorKind, bool)>[
        (GoogleApiException(401, 'expired token'), SyncErrorKind.auth, true),
        (
          GoogleApiException(429, 'slow down', retryAfterSec: 1),
          SyncErrorKind.rateLimited,
          false,
        ),
        (http.ClientException('offline'), SyncErrorKind.network, false),
      ];
      for (final (error, kind, auth) in cases) {
        await resetTestDb(db);
        await _seedQueuedEvent(db);
        final engine = SyncEngine(db, clientFactory: () => _FlakyPush(error));

        await engine.syncNow();

        expect(engine.errorKind, kind, reason: 'error=$error');
        expect(engine.status, SyncStatus.error);
        expect(engine.authFailure, auth);
        final op = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals('op-e1'))).getSingle();
        expect(op.attempts, 1);
        expect(op.nextTryAt, isNotNull);
      }
    },
  );

  test('outbox drains on a later successful retry', () async {
    await _seedQueuedEvent(db);
    final fake = _FlakyPush(http.ClientException('offline'));
    final engine = SyncEngine(db, clientFactory: () => fake);

    await engine.syncNow();
    expect(engine.errorKind, SyncErrorKind.network);
    expect(await db.select(db.outbox).get(), hasLength(1));

    await engine.retryFailed('op-e1');
    await engine.syncNow();

    expect(await db.select(db.outbox).get(), isEmpty);
    expect(engine.status, SyncStatus.synced);
    expect(engine.errorKind, SyncErrorKind.none);
    final event = await (db.select(
      db.events,
    )..where((e) => e.id.equals('e1'))).getSingle();
    expect(event.remoteId, 'remote-ok');
    expect(event.dirty, isFalse);
  });

  test('stale 401 silent refresh re-pushes and drains the outbox', () async {
    await _seedQueuedEvent(db);
    const account = 'a@example.com';
    final auth = _RecoveringAuth(account, 'stale-a');
    final pushesWithFreshToken = <http.Request>[];

    final result = await http.runWithClient(
      () => syncGoogleAccount(
        db: db,
        auth: auth,
        account: account,
        signedInAccounts: const [account],
      ),
      () => MockClient((request) async {
        if (request.headers['Authorization'] == 'Bearer fresh-$account') {
          if (request.method == 'POST' || request.method == 'PATCH') {
            pushesWithFreshToken.add(request);
          }
        }
        if (request.headers['Authorization'] == 'Bearer stale-a') {
          return http.Response('{"error":{"code":401}}', 401);
        }
        if (request.method == 'POST' || request.method == 'PATCH') {
          return http.Response('{"id":"remote-1","etag":"e1"}', 200);
        }
        if (request.url.path.contains('/calendarList')) {
          return http.Response(
            '{"items":[{"id":"r1","summary":"Calendar","accessRole":"owner"}]}',
            200,
          );
        }
        return http.Response('{"items":[]}', 200);
      }),
    );

    expect(result.skipped, isFalse);
    expect(result.authFailure, isFalse);
    expect(result.status, isNot(SyncStatus.error));
    expect(auth.invalidations[account], 1);
    expect(auth.acquisitions[account], 2);

    // The queued create must be pushed with the fresh token and removed.
    // The event row itself may be removed by the subsequent full resync, so
    // assert on the observed request and the drained outbox, not the row.
    expect(pushesWithFreshToken, isNotEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
  });
}
