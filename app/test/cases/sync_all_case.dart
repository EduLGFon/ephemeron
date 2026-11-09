import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/auth/application/auth_providers.dart';
import 'package:ephemeron/features/auth/data/backend_auth.dart';
import 'package:ephemeron/features/sync/application/sync_providers.dart';
import 'package:ephemeron/features/sync/data/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
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
}
