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

/// Highest-priority Google failure from the last sync run. Null means no
/// Google issue. Backend (and Microsoft) failures are tracked separately so
/// they never raise a Google reconnect prompt.
final syncIssueProvider = NotifierProvider<SyncIssueNotifier, SyncErrorKind?>(
  SyncIssueNotifier.new,
);

class SyncIssueNotifier extends Notifier<SyncErrorKind?> {
  @override
  SyncErrorKind? build() => null;

  void set(SyncErrorKind? issue) => state = issue;
}

/// Persisted, non-personal flag: the last Google sync needed renewed
/// permission. Drives the global banner even when the account list has not
/// loaded yet. The in-memory reconsent list remains the source of account
/// names; this flag never stores an email.
///
/// Null means "not loaded yet". The banner treats null as unknown instead of
/// false so a persisted flag cannot flash off on the first frame. When the
/// settings repository is already resolved, [build] seeds synchronously.
final googleReconnectNeededProvider =
    NotifierProvider<GoogleReconnectNeededNotifier, bool?>(
      GoogleReconnectNeededNotifier.new,
    );

class GoogleReconnectNeededNotifier extends Notifier<bool?> {
  bool _hasSetValue = false;

  @override
  bool? build() {
    final repo = ref.read(settingsRepositoryProvider).value;
    if (repo != null) return repo.googleReconnectNeeded;
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      if (_hasSetValue) return;
      state = repo.googleReconnectNeeded;
    } catch (_) {
      // Prefs unavailable: settle on the conservative in-memory value.
      if (!_hasSetValue) state = false;
    }
  }

  Future<void> set(bool value) async {
    _hasSetValue = true;
    state = value;
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.setGoogleReconnectNeeded(value);
    } catch (_) {
      // Persistence is best-effort; in-memory state still drives the UI.
    }
  }
}

int _googleIssuePriority(SyncErrorKind? kind) => switch (kind) {
  SyncErrorKind.auth => 5,
  SyncErrorKind.rateLimited => 4,
  SyncErrorKind.network => 3,
  SyncErrorKind.server => 2,
  SyncErrorKind.unknown => 1,
  SyncErrorKind.none || null => 0,
};

SyncErrorKind? _higherGoogleIssue(
  SyncErrorKind? current,
  SyncErrorKind? next,
) =>
    _googleIssuePriority(next) > _googleIssuePriority(current) ? next : current;

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
  bool _running = false;

  @override
  SyncStatus build() => SyncStatus.synced;

  Future<void> syncNow() async {
    if (_running) return;
    _running = true;
    debugPrint('[sync] notifier syncNow start');
    state = SyncStatus.syncing;
    try {
      final googleAuth = ref.read(googleAuthProvider);
      if (googleAuth.accounts.isEmpty) {
        await googleAuth.restore();
      }
      final googleAccounts = googleAuth.accounts;
      final msAuth = ref.read(microsoftAuthProvider);
      await msAuth.restore();
      final msAccounts = msAuth.accounts;
      if (googleAccounts.isEmpty && msAccounts.isEmpty) {
        debugPrint('[sync] not signed in: offline');
        state = SyncStatus.offline;
        ref.read(syncIssueProvider.notifier).set(null);
        ref.read(googleReconsentAccountsProvider.notifier).set(const []);
        await ref.read(googleReconnectNeededProvider.notifier).set(false);
        return;
      }
      bool anyAttempted = false;
      bool anyPulled = false;
      bool hasAuthFailure = false;
      bool hasRealError = false;
      SyncErrorKind? googleIssue;

      // Google
      final needReconnectGoogle = <String>[];
      bool googleAttempted = false;
      bool googleUnavailable = false;
      if (googleAccounts.isNotEmpty) {
        final db = ref.read(appDatabaseProvider);
        for (final acct in googleAccounts) {
          try {
            // Acquire the token before building the engine. A missing token
            // is transient: skip this account and retry later instead of
            // turning it into a 401 auth failure.
            final result = await syncGoogleAccount(
              db: db,
              auth: googleAuth,
              account: acct,
              signedInAccounts: googleAccounts,
            );
            if (result.skipped) continue;
            if (result.authFailure) {
              // Definitive platform denial or repeated Google auth response.
              needReconnectGoogle.add(acct);
              hasAuthFailure = true;
              googleAttempted = true;
              anyAttempted = true;
              googleIssue = _higherGoogleIssue(googleIssue, SyncErrorKind.auth);
              continue;
            }
            if (!result.attempted) {
              googleUnavailable = true;
              continue;
            }
            googleAttempted = true;
            anyAttempted = true;
            if (result.status == SyncStatus.synced) {
              anyPulled = true;
            } else if (result.status == SyncStatus.error) {
              hasRealError = true;
              googleIssue = _higherGoogleIssue(
                googleIssue,
                result.errorKind == SyncErrorKind.none
                    ? SyncErrorKind.unknown
                    : result.errorKind,
              );
            }
          } catch (e) {
            debugPrint('[sync] google account failed type=${e.runtimeType}');
            hasRealError = true;
            anyAttempted = true;
            googleAttempted = true;
            googleIssue = _higherGoogleIssue(
              googleIssue,
              SyncErrorKind.unknown,
            );
          }
        }
        if (googleAttempted) {
          ref
              .read(googleReconsentAccountsProvider.notifier)
              .set(needReconnectGoogle);
        }
        final reconsent = ref.read(googleReconsentAccountsProvider);
        if (reconsent.isNotEmpty) googleIssue = SyncErrorKind.auth;
        if (!anyPulled &&
            !hasAuthFailure &&
            !hasRealError &&
            googleUnavailable) {
          googleIssue = _higherGoogleIssue(googleIssue, SyncErrorKind.network);
        }
        ref
            .read(syncIssueProvider.notifier)
            .set(googleIssue == SyncErrorKind.none ? null : googleIssue);
        if (googleAttempted) {
          await ref
              .read(googleReconnectNeededProvider.notifier)
              .set(needReconnectGoogle.isNotEmpty);
        }
      } else {
        ref.read(syncIssueProvider.notifier).set(null);
        ref.read(googleReconsentAccountsProvider.notifier).set(const []);
        await ref.read(googleReconnectNeededProvider.notifier).set(false);
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
              signedInAccounts: msAccounts,
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
            debugPrint('[sync] microsoft account failed type=${e.runtimeType}');
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
          // Do not invalidate windowOccurrencesProvider here: it is a Drift
          // stream over this database and the rebuild transaction emits the
          // complete new window. Invalidating re-subscribes the stream and can
          // briefly surface AsyncLoading, making events disappear/reappear.
        } catch (e) {
          debugPrint(
            '[sync] occurrence cache rebuild failed type=${e.runtimeType}',
          );
        }
      }
    } catch (e) {
      debugPrint('[sync] notifier unexpected error type=${e.runtimeType}');
      state = SyncStatus.error;
    } finally {
      _running = false;
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
