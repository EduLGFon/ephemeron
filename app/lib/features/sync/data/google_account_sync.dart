// Per-account Google sync with silent token recovery.
//
// A missing token is transient: the account is skipped and the next sync
// retries, without raising the reconnect banner. A Google auth rejection
// invalidates that account's cached token and retries the run once with a
// fresh silent token before asking the user to reconnect.
//
// PRIVACY: never log tokens, emails, account ids, or raw exception text.
import 'package:flutter/foundation.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/remote/google_api_client.dart';
import '../../auth/data/google_auth.dart';
import '../../auth/domain/account_email.dart';
import 'sync_engine.dart';

/// Outcome of one account's sync attempt.
class GoogleAccountSyncResult {
  const GoogleAccountSyncResult({
    required this.attempted,
    required this.skipped,
    required this.authFailure,
    required this.status,
    required this.errorKind,
  });

  const GoogleAccountSyncResult.skipped()
    : attempted = false,
      skipped = true,
      authFailure = false,
      status = SyncStatus.offline,
      errorKind = SyncErrorKind.none;

  /// No token yet. The account is skipped without a reconnect prompt.
  const GoogleAccountSyncResult.unavailable()
    : attempted = false,
      skipped = false,
      authFailure = false,
      status = SyncStatus.offline,
      errorKind = SyncErrorKind.network;

  /// True when a [SyncEngine] actually ran for this account.
  final bool attempted;

  /// True when another engine was already syncing.
  final bool skipped;
  final bool authFailure;
  final SyncStatus status;
  final SyncErrorKind errorKind;
}

/// Syncs one Google account, recovering a rejected access token once.
///
/// [auth] must be account-isolated: tokens are acquired per account through
/// [GoogleAuth.accessTokenFor] and invalidated per account.
Future<GoogleAccountSyncResult> syncGoogleAccount({
  required AppDatabase db,
  required GoogleAuth auth,
  required String account,
  required List<String> signedInAccounts,
}) async {
  String? token;
  try {
    token = await auth.accessTokenFor(account);
  } catch (_) {
    // PRIVACY: the exception type/text is not logged; it may mention data.
    return const GoogleAccountSyncResult.unavailable();
  }
  if (token == null) {
    // A definitive platform denial (for example a stored account that no
    // longer matches the signed-in user) is not transient. Ask for reconnect
    // without prompting. Every other null token is a transient skip.
    final denied = auth.accountsNeedingReconnect.any(
      (email) => isSameAccountEmail(email, account),
    );
    if (denied) {
      debugPrint('[sync] Google account needs reconnect');
      return const GoogleAccountSyncResult(
        attempted: false,
        skipped: false,
        authFailure: true,
        status: SyncStatus.error,
        errorKind: SyncErrorKind.auth,
      );
    }
    debugPrint('[sync] Google account skipped: no token yet');
    return const GoogleAccountSyncResult.unavailable();
  }

  var retriedAfterAuthFailure = false;
  while (true) {
    final engine = SyncEngine(
      db,
      clientFactory: () => HttpGoogleApiClient(
        // Reuse the token acquired for this run. Never fall back to the
        // global/active-account token: a missing token must stay offline.
        accessToken: () async => token,
      ),
      account: account,
      signedInAccounts: signedInAccounts,
    );
    await engine.syncNow();
    if (engine.skipped) return const GoogleAccountSyncResult.skipped();
    if (!engine.authFailure) {
      return GoogleAccountSyncResult(
        attempted: true,
        skipped: false,
        authFailure: false,
        status: engine.status,
        errorKind: engine.errorKind,
      );
    }

    // Google rejected this account's token or grant. Clear only this
    // account's cached access token. A 403 is a definitive authorization
    // verdict for the current grant; a 401 may be a stale cached token, so
    // retry that run once silently before asking the user to reconnect.
    await auth.invalidateAccessTokenFor(account);
    if (retriedAfterAuthFailure || engine.authStatus == 403) {
      debugPrint('[sync] Google auth rejected; reconnect required');
      return const GoogleAccountSyncResult(
        attempted: true,
        skipped: false,
        authFailure: true,
        status: SyncStatus.error,
        errorKind: SyncErrorKind.auth,
      );
    }
    try {
      final fresh = await auth.accessTokenFor(account);
      if (fresh == null) {
        // The silent refresh is transient/unavailable; do not claim the
        // account needs reconnection. The next sync retries.
        debugPrint('[sync] Google token refresh unavailable; will retry');
        return const GoogleAccountSyncResult(
          attempted: true,
          skipped: false,
          authFailure: false,
          status: SyncStatus.offline,
          errorKind: SyncErrorKind.network,
        );
      }
      token = fresh;
    } catch (_) {
      return const GoogleAccountSyncResult(
        attempted: true,
        skipped: false,
        authFailure: false,
        status: SyncStatus.offline,
        errorKind: SyncErrorKind.network,
      );
    }
    retriedAfterAuthFailure = true;
  }
}
