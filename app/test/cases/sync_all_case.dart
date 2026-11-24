import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/auth/application/auth_providers.dart';
import 'package:ephemeron/features/auth/data/backend_auth.dart';
import 'package:ephemeron/features/sync/application/sync_providers.dart';
import 'package:ephemeron/features/sync/data/microsoft_graph_client.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fixtures.dart';

class _FakeSyncStatusNotifier extends SyncStatusNotifier {
  _FakeSyncStatusNotifier(this._status);
  final SyncStatus _status;

  @override
  SyncStatus build() => _status;
}

class _FakeBackendSyncStatusNotifier extends BackendSyncStatusNotifier {
  _FakeBackendSyncStatusNotifier(this._status);
  final SyncStatus _status;

  @override
  SyncStatus build() => _status;
}

class _RestoringBackendAuth extends BackendAuth {
  bool _signedIn = false;

  @override
  bool get isSignedIn => _signedIn;

  @override
  Future<String?> restore() async {
    _signedIn = true;
    return 'user@example.com';
  }
}

late AppDatabase db;

void main() {
  setUpAll(() async {
    db = newTestDb();
  });
  tearDownAll(() async {});
  setUp(() async {
    await resetTestDb(db);
  });
  test('combinedSyncStatusProvider precedence', () {
    SyncStatus check(SyncStatus g, SyncStatus b) {
      final container = ProviderContainer(
        overrides: [
          syncStatusProvider.overrideWith(() => _FakeSyncStatusNotifier(g)),
          backendSyncStatusProvider.overrideWith(
            () => _FakeBackendSyncStatusNotifier(b),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(combinedSyncStatusProvider);
    }

    expect(check(SyncStatus.syncing, SyncStatus.synced), SyncStatus.syncing);
    expect(check(SyncStatus.synced, SyncStatus.syncing), SyncStatus.syncing);
    expect(check(SyncStatus.error, SyncStatus.synced), SyncStatus.error);
    expect(check(SyncStatus.synced, SyncStatus.error), SyncStatus.error);
    expect(check(SyncStatus.synced, SyncStatus.offline), SyncStatus.synced);
    expect(check(SyncStatus.offline, SyncStatus.synced), SyncStatus.synced);
    expect(check(SyncStatus.offline, SyncStatus.offline), SyncStatus.offline);
  });

  test('BackendSyncStatusNotifier.syncNow restores before syncing', () async {
    final auth = _RestoringBackendAuth();

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        backendAuthProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);

    await container.read(backendSyncStatusProvider.notifier).syncNow();

    expect(auth.isSignedIn, isTrue);
    expect(container.read(backendSyncStatusProvider), SyncStatus.offline);
  });

  test('microsoftFailureKind classifies escaped Graph failures', () {
    SyncErrorKind kind(int status) =>
        microsoftFailureKind(MicrosoftGraphException(status, 'boom'));

    expect(kind(401), SyncErrorKind.auth);
    expect(kind(403), SyncErrorKind.auth);
    expect(kind(429), SyncErrorKind.rateLimited);
    expect(kind(500), SyncErrorKind.server);
    expect(kind(503), SyncErrorKind.server);
    expect(kind(400), SyncErrorKind.unknown);
    expect(kind(404), SyncErrorKind.unknown);
    expect(kind(0), SyncErrorKind.unknown);
    expect(microsoftFailureKind(StateError('boom')), SyncErrorKind.unknown);
  });
}
