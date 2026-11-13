// Sync status and final-status matrix: combined precedence, user-facing
// messages, and the Google notifier's synced/offline/error classification
// using an injected http client instead of real network I/O.
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/auth/application/auth_providers.dart';
import 'package:ephemeron/features/auth/data/google_auth.dart';
import 'package:ephemeron/features/auth/data/microsoft_auth.dart';
import 'package:ephemeron/features/settings/presentation/settings_screen.dart';
import 'package:ephemeron/features/sync/application/sync_providers.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

class _FixedSyncStatusNotifier extends SyncStatusNotifier {
  _FixedSyncStatusNotifier(this.value);

  final SyncStatus value;

  @override
  SyncStatus build() => value;
}

class _FixedBackendSyncStatusNotifier extends BackendSyncStatusNotifier {
  _FixedBackendSyncStatusNotifier(this.value);

  final SyncStatus value;

  @override
  SyncStatus build() => value;
}

class _FakeGoogleAuth extends GoogleAuth {
  _FakeGoogleAuth({required List<String> accounts, required this.tokenFor})
    : accountList = [...accounts];

  final List<String> accountList;
  final Map<String, String?> tokenFor;
  String? _active;

  @override
  List<String> get accounts => List.unmodifiable(accountList);

  @override
  Future<void> setActiveAccount(String email) async {
    _active = email;
  }

  @override
  Future<String?> accessToken() async => tokenFor[_active];

  @override
  Future<String?> accessTokenFor(String account) async => tokenFor[account];
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

class _SyncHarness {
  _SyncHarness(AppDatabase db, this.auth)
    : container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          googleAuthProvider.overrideWithValue(auth),
          microsoftAuthProvider.overrideWithValue(_FakeMicrosoftAuth()),
        ],
      );

  final _FakeGoogleAuth auth;
  final ProviderContainer container;

  SyncStatus get status => container.read(syncStatusProvider);

  SyncErrorKind? get issue => container.read(syncIssueProvider);

  Future<void> run(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return http.runWithClient(
      () => container.read(syncStatusProvider.notifier).syncNow(),
      () => MockClient(handler),
    );
  }

  Future<void> dispose(AppDatabase db) async {
    container.dispose();
    await db.close();
  }
}

Future<http.Response> _ok(http.Request request) async =>
    http.Response('{"items":[]}', 200);

Future<http.Response> Function(http.Request) _error(int status) =>
    (request) async => http.Response('{"error":{"code":$status}}', status);

Future<http.Response> _network(http.Request request) async =>
    throw http.ClientException('offline');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('combined status precedence across Google and backend', () {
    SyncStatus check(SyncStatus google, SyncStatus backend) {
      final container = ProviderContainer(
        overrides: [
          syncStatusProvider.overrideWith(
            () => _FixedSyncStatusNotifier(google),
          ),
          backendSyncStatusProvider.overrideWith(
            () => _FixedBackendSyncStatusNotifier(backend),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(combinedSyncStatusProvider);
    }

    expect(check(SyncStatus.synced, SyncStatus.synced), SyncStatus.synced);
    expect(check(SyncStatus.offline, SyncStatus.synced), SyncStatus.synced);
    expect(check(SyncStatus.synced, SyncStatus.offline), SyncStatus.synced);
    expect(check(SyncStatus.offline, SyncStatus.offline), SyncStatus.offline);
    expect(check(SyncStatus.error, SyncStatus.synced), SyncStatus.error);
    expect(check(SyncStatus.synced, SyncStatus.error), SyncStatus.error);
    expect(check(SyncStatus.error, SyncStatus.offline), SyncStatus.error);
    expect(check(SyncStatus.syncing, SyncStatus.synced), SyncStatus.syncing);
    expect(check(SyncStatus.synced, SyncStatus.syncing), SyncStatus.syncing);
    expect(check(SyncStatus.syncing, SyncStatus.offline), SyncStatus.syncing);
    // The implementation gives an in-flight sync priority over a previous
    // error so the spinner stays visible while retrying.
    expect(check(SyncStatus.error, SyncStatus.syncing), SyncStatus.syncing);
  });

  test('syncIssueMessage covers every kind and the no-issue state', () {
    expect(
      syncIssueMessage(SyncErrorKind.auth),
      'Sync needs permission. Reconnect your Google account.',
    );
    expect(
      syncIssueMessage(SyncErrorKind.rateLimited),
      'Google is rate-limiting sync. Try again later.',
    );
    expect(
      syncIssueMessage(SyncErrorKind.network),
      'No connection. Changes are queued.',
    );
    expect(
      syncIssueMessage(SyncErrorKind.server),
      'Google returned an error. Try again later.',
    );
    expect(syncIssueMessage(SyncErrorKind.unknown), 'Sync failed. Try again.');
    expect(syncIssueMessage(SyncErrorKind.none), 'Sync failed. Try again.');
    expect(syncIssueMessage(null), 'Sync failed. Try again.');
  });

  test('Google notifier maps every final status and issue kind', () async {
    final cases =
        <
          (
            String,
            Future<http.Response> Function(http.Request),
            SyncStatus,
            SyncErrorKind?,
          )
        >[
          ('synced', _ok, SyncStatus.synced, null),
          ('auth', _error(401), SyncStatus.error, SyncErrorKind.auth),
          (
            'rateLimited',
            _error(429),
            SyncStatus.error,
            SyncErrorKind.rateLimited,
          ),
          ('network', _network, SyncStatus.error, SyncErrorKind.network),
          ('server', _error(500), SyncStatus.error, SyncErrorKind.server),
          ('unknown', _error(400), SyncStatus.error, SyncErrorKind.unknown),
        ];

    for (final entry in cases) {
      final db = _db();
      final auth = _FakeGoogleAuth(
        accounts: const ['a@example.com'],
        tokenFor: const {'a@example.com': 'token-a'},
      );
      final harness = _SyncHarness(db, auth);
      try {
        await harness.run(entry.$2);
        expect(harness.status, entry.$3, reason: entry.$1);
        expect(harness.issue, entry.$4, reason: entry.$1);
      } finally {
        await harness.dispose(db);
      }
    }
  });

  test(
    'signed-out notifier reports offline without calling the network',
    () async {
      final db = _db();
      final auth = _FakeGoogleAuth(accounts: const [], tokenFor: const {});
      final harness = _SyncHarness(db, auth);
      var requests = 0;
      try {
        await harness.run((request) async {
          requests++;
          return http.Response('{"items":[]}', 200);
        });

        expect(harness.status, SyncStatus.offline);
        expect(harness.issue, isNull);
        expect(requests, 0);
      } finally {
        await harness.dispose(db);
      }
    },
  );

  test(
    'partial auth and rate failures keep auth issue; a clean run clears it',
    () async {
      final db = _db();
      final auth = _FakeGoogleAuth(
        accounts: const [
          'ok@example.com',
          'auth@example.com',
          'rate@example.com',
        ],
        tokenFor: const {
          'ok@example.com': 'token-ok',
          'auth@example.com': 'token-auth',
          'rate@example.com': 'token-rate',
        },
      );
      final harness = _SyncHarness(db, auth);
      try {
        await harness.run((request) async {
          final token = request.headers['Authorization'];
          if (token == 'Bearer token-auth') return _error(401)(request);
          if (token == 'Bearer token-rate') return _error(429)(request);
          return _ok(request);
        });

        expect(harness.status, SyncStatus.error);
        expect(harness.issue, SyncErrorKind.auth);
        expect(harness.container.read(googleReconsentAccountsProvider), [
          'auth@example.com',
        ]);
        expect(
          syncIssueMessage(harness.issue),
          'Sync needs permission. Reconnect your Google account.',
        );

        // A later clean run with the remaining account is a full success and
        // must clear the previous issue and reconnect state.
        auth.accountList
          ..clear()
          ..add('ok@example.com');
        await harness.run(_ok);

        expect(harness.status, SyncStatus.synced);
        expect(harness.issue, isNull);
        expect(
          harness.container.read(googleReconsentAccountsProvider),
          isEmpty,
        );
      } finally {
        await harness.dispose(db);
      }
    },
  );
}
