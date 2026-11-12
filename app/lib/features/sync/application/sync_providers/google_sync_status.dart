part of '../sync_providers.dart';

/// Accounts whose last sync hit an auth/permission error (expired token,
/// revoked access, or a grant missing Calendar/Tasks scope). The account
/// screen shows a reconnect banner for these. Cleared per account after a
/// successful re-grant; re-added by the next failing sync.
final googleReconsentAccountsProvider =
    NotifierProvider<GoogleReconsentAccounts, List<String>>(
      GoogleReconsentAccounts.new,
    );

class GoogleReconsentAccounts extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void set(List<String> accounts) => state = List.unmodifiable(accounts);

  void clear(String account) =>
      state = state.where((a) => a != account).toList();
}

final microsoftReconsentAccountsProvider =
    NotifierProvider<MicrosoftReconsentAccounts, List<String>>(
      MicrosoftReconsentAccounts.new,
    );

class MicrosoftReconsentAccounts extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void set(List<String> accounts) => state = List.unmodifiable(accounts);

  void clear(String account) =>
      state = state.where((a) => a != account).toList();
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.synced;

  Future<void> syncNow() async {
    debugPrint('[sync] notifier syncNow start');
    state = SyncStatus.syncing;
    try {
      final googleAuth = ref.read(googleAuthProvider);
      final googleAccounts = googleAuth.accounts;
      final msAuth = ref.read(microsoftAuthProvider);
      await msAuth.restore();
      final msAccounts = msAuth.accounts;
      if (googleAccounts.isEmpty && msAccounts.isEmpty) {
        debugPrint('[sync] not signed in: offline');
        state = SyncStatus.offline;
        return;
      }
      bool anyAttempted = false;
      bool anyPulled = false;
      bool hasAuthFailure = false;
      bool hasRealError = false;

      // Google
      final needReconnectGoogle = <String>[];
      bool googleAttempted = false;
      if (googleAccounts.isNotEmpty) {
        for (final acct in googleAccounts) {
          try {
            await googleAuth.setActiveAccount(acct);
            final engine = SyncEngine(
              ref.read(appDatabaseProvider),
              clientFactory: () {
                try {
                  return HttpGoogleApiClient(
                    accessToken: () => googleAuth.accessToken(),
                  );
                } catch (_) {
                  return null;
                }
              },
              account: acct,
            );
            debugPrint('[sync] signed in ($acct), calling engine');
            await engine.syncNow();
            if (engine.skipped) continue;
            googleAttempted = true;
            anyAttempted = true;
            if (engine.authFailure) {
              needReconnectGoogle.add(acct);
              hasAuthFailure = true;
            } else if (engine.status == SyncStatus.synced) {
              anyPulled = true;
            } else if (engine.status == SyncStatus.error) {
              hasRealError = true;
            }
          } catch (e) {
            debugPrint('[sync] google account failed: $e');
            hasRealError = true;
            anyAttempted = true;
            googleAttempted = true;
          }
        }
        if (googleAttempted) {
          ref
              .read(googleReconsentAccountsProvider.notifier)
              .set(needReconnectGoogle);
        }
      }

      // Microsoft
      final needReconnectMs = <String>[];
      if (msAccounts.isNotEmpty) {
        for (final acct in msAccounts) {
          try {
            await msAuth.setActiveAccount(acct);
            final client = HttpMicrosoftGraphClient(
              accessToken: () => msAuth.accessTokenFor(acct),
            );
            final engine = MicrosoftSyncEngine(
              ref.read(appDatabaseProvider),
              client,
              acct,
            );
            final result = await engine.syncNow();
            if (result.authFailure) {
              needReconnectMs.add(acct);
              hasAuthFailure = true;
            } else {
              anyPulled = true;
            }
            anyAttempted = true;
          } catch (e) {
            debugPrint('[sync] microsoft account failed: $e');
            hasRealError = true;
            anyAttempted = true;
          }
        }
        ref
            .read(microsoftReconsentAccountsProvider.notifier)
            .set(needReconnectMs);
      }

      if (!anyAttempted) {
        state = SyncStatus.offline;
        return;
      }
      SyncStatus finalStatus;
      if (hasAuthFailure || hasRealError) {
        finalStatus = SyncStatus.error;
      } else if (anyPulled) {
        finalStatus = SyncStatus.synced;
      } else {
        finalStatus = SyncStatus.offline;
      }
      state = finalStatus;
      if (finalStatus == SyncStatus.synced) {
        unawaited(ref.read(lastGoogleSyncAtProvider.notifier).recordNow());
      }
      if (anyPulled) {
        // Rebuild occurrence cache once after both loops.
        try {
          final range = ref.read(calendarCacheRangeProvider);
          final n = await ref
              .read(occurrenceRepositoryProvider)
              .rebuildWindow(
                windowStartUtc: range.fromUtc,
                windowEndUtc: range.toUtc,
              );
          debugPrint('[sync] occurrence cache rebuilt rows=$n');
          ref.invalidate(windowOccurrencesProvider(range));
        } catch (e) {
          debugPrint('[sync] occurrence cache rebuild failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[sync] notifier unexpected error: $e');
      state = SyncStatus.error;
    } finally {
      if (state == SyncStatus.syncing) {
        state = SyncStatus.offline;
      }
    }
  }
}

/// Last successful Google sync. Reactive cache of the persisted value in
/// SettingsRepository; drives title freshness colors.
final lastGoogleSyncAtProvider =
    NotifierProvider<LastGoogleSyncNotifier, DateTime?>(
      LastGoogleSyncNotifier.new,
    );

class LastGoogleSyncNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      state = repo.lastGoogleSyncAt;
    } catch (_) {
      // Prefs unavailable: stay null (titles render gray).
    }
  }

  Future<void> recordNow() async {
    state = DateTime.now().toUtc();
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.setLastGoogleSyncAt(state);
    } catch (_) {
      // Persistence is best-effort; in-memory state still drives the UI.
    }
  }
}
