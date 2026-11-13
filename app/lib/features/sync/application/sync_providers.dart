// Sync providers: engine, status, manual triggers, auto-sync schedule.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/db_provider.dart';
import '../../../data/remote/backend_sync_api.dart';
import '../../../data/remote/google_api_client.dart';
import '../../auth/application/auth_providers.dart';
import '../data/microsoft_sync_engine.dart';
import '../data/microsoft_graph_client.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/data/settings_repository.dart';
import '../../../core/power/power_saving_manager.dart';
import '../data/backend_sync_engine.dart';
import '../data/background_sync.dart';
import '../data/sync_engine.dart';

part 'sync_providers/google_sync_status.dart';
part 'sync_providers/google_auto_sync.dart';
part 'sync_providers/backend_sync.dart';

final googleApiClientProvider = Provider<GoogleApiClient>((ref) {
  final auth = ref.watch(googleAuthProvider);
  return HttpGoogleApiClient(accessToken: auth.accessToken);
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final accounts = ref.watch(googleAccountsProvider);
  return SyncEngine(
    db,
    clientFactory: () {
      try {
        return ref.read(googleApiClientProvider);
      } catch (_) {
        return null;
      }
    },
    signedInAccounts: accounts,
  );
});

final failedChangesProvider = StreamProvider((ref) {
  return ref.watch(syncEngineProvider).watchFailed();
});

/// Failed or retrying outbox rows for the user-facing Sync issues screen.
final syncOutboxIssuesProvider = StreamProvider((ref) {
  return ref.watch(syncEngineProvider).watchOutboxIssues();
});

/// Per-calendar/task-list errors recorded in syncState.
final syncStateIssuesProvider = StreamProvider((ref) {
  return ref.watch(syncEngineProvider).watchSyncStateIssues();
});

/// Combined status across Google/Microsoft (`syncStatusProvider`) and backend
/// (`backendSyncStatusProvider`) syncs. Syncing/error take precedence; a synced
/// side wins over an offline side so a signed-out backend does not make the
/// app look offline when Google is fine.
final combinedSyncStatusProvider = Provider<SyncStatus>((ref) {
  final google = ref.watch(syncStatusProvider);
  final backend = ref.watch(backendSyncStatusProvider);
  if (google == SyncStatus.syncing || backend == SyncStatus.syncing) {
    return SyncStatus.syncing;
  }
  if (google == SyncStatus.error || backend == SyncStatus.error) {
    return SyncStatus.error;
  }
  if (google == SyncStatus.synced || backend == SyncStatus.synced) {
    return SyncStatus.synced;
  }
  return SyncStatus.offline;
});

/// Manual sync-all action (title tap): starts Google/Microsoft and backend
/// syncs concurrently, then reschedules both countdowns.
final syncAllProvider = Provider<Future<void> Function()>((ref) {
  return () => Future.wait<void>([
    ref.read(googleAutoSyncServiceProvider).syncNowAndReschedule(),
    ref.read(backendAutoSyncServiceProvider).syncNowAndReschedule(),
  ]);
});
