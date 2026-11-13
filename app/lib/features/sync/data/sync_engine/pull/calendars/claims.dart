part of '../../../sync_engine.dart';

extension on SyncEngine {
  /// Whether [cal] may be pulled under the active account.
  ///
  /// A calendar stamped to the active account is always pulled. A calendar
  /// stamped to another signed-in account belongs to that owner and is
  /// skipped here, so a shared calendar is not fetched once per account.
  /// A calendar whose stamp names an account that is not signed in is pulled
  /// by a single deterministic reader recorded in syncState, so the same
  /// calendar is not pulled by every account in turn. With an unknown account
  /// list, another owner's shared calendar fails closed instead of pulling
  /// once per account. Entries that are freeBusyReader-only have no event
  /// details and are skipped.
  Future<bool> _pullableCalendar(Calendar cal) async {
    final remoteId = cal.remoteId;
    final discovered = _accountCalendarIds;
    final readable = _readableCalendarIds;
    if (remoteId != null &&
        discovered != null &&
        readable != null &&
        discovered.contains(remoteId) &&
        !readable.contains(remoteId)) {
      return false;
    }
    if (account == null) return true;
    final owner = cal.googleAccount;
    if (owner == account) return true;
    if (owner == null) {
      // Legacy unstamped rows keep discovery gating and are not claimed:
      // there is no host account whose absence needs a reader.
      if (discovered == null) return true;
      return remoteId == null || discovered.contains(remoteId);
    }
    final signedIn = signedInAccounts;
    if (signedIn == null) {
      // Fail closed: without the signed-in set we cannot tell another active
      // account's shared calendar from a signed-out owner's. Pulling would
      // duplicate a shared calendar once per account, so only the stamped
      // owner above may pull.
      return false;
    }
    if (signedIn.contains(owner)) return false;
    if (remoteId == null) return false;
    final key = 'cal:reader:$remoteId';
    final reader = await _syncValue(key);
    if (reader == account) return true;
    if (reader != null && signedIn.contains(reader)) return false;
    // Claim only when the calendar is actually readable under this account,
    // otherwise a freeBusyReader or inaccessible entry would occupy the slot.
    if (readable == null || !readable.contains(remoteId)) return false;
    await _setSyncValue(key, account!);
    debugPrint('[sync] claimed shared calendar reader');
    return true;
  }

  /// Best-effort release of a shared-calendar reader claim after a failed
  /// pull. Clears only when the key still names the active account so a
  /// concurrent account's claim is never stolen. Never throws into the pull
  /// loop: a cleanup failure must not abort remaining calendars.
  Future<void> _clearReaderClaim(String? remoteId) async {
    final active = account;
    if (remoteId == null || active == null) return;
    final key = 'cal:reader:$remoteId';
    try {
      final reader = await _syncValue(key);
      if (reader != active) return;
      await (_db.delete(_db.syncState)..where((s) => s.key.equals(key))).go();
      debugPrint('[sync] released shared calendar reader');
    } catch (e) {
      debugPrint('[sync] reader claim cleanup failed type=${e.runtimeType}');
    }
  }

  /// Removes stale legacy `cal:<localId>:token` rows once the v2 key exists.
  /// Runs before every pull so old installs are cleaned on the next normal
  /// sync, including runs where a specific calendar pull fails.
  Future<void> _cleanupLegacyCalendarTokens() async {
    final rows = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.like('cal:%:token'))).get();
    if (rows.isEmpty) return;
    final v2Keys = {
      for (final row in rows)
        if (row.key.startsWith('cal:v2:')) row.key,
    };
    for (final row in rows) {
      final key = row.key;
      if (key.startsWith('cal:v2:')) continue;
      if (!key.startsWith('cal:') || !key.endsWith(':token')) continue;
      final localId = key.substring(
        'cal:'.length,
        key.length - ':token'.length,
      );
      if (localId.isEmpty || localId.contains(':')) continue;
      if (!v2Keys.contains('cal:v2:$localId:token')) continue;
      await (_db.delete(_db.syncState)..where((s) => s.key.equals(key))).go();
    }
  }

  /// Conservative cleanup for `cal:reader:<remoteId>` claims.
  ///
  /// A claim is stale when its calendar row is gone, disabled or soft-deleted,
  /// or when the true owner is signed in again (the owner pulls directly).
  /// A claim is kept while its reader is signed in and the owner is absent.
  /// With an unknown account list only provably stale rows are removed.
  Future<void> _cleanupReaderClaims() async {
    final claims = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.like('cal:reader:%'))).get();
    if (claims.isEmpty) return;
    final calendars = await (_db.select(
      _db.calendars,
    )..where((c) => c.source.equals('google') & c.remoteId.isNotNull())).get();
    final byRemote = <String, List<Calendar>>{};
    for (final calendar in calendars) {
      byRemote.putIfAbsent(calendar.remoteId!, () => []).add(calendar);
    }
    for (final claim in claims) {
      final remoteId = claim.key.substring('cal:reader:'.length);
      final rows = byRemote[remoteId];
      if (rows == null || rows.isEmpty) {
        await _deleteReaderClaim(claim.key);
        continue;
      }
      if (rows.any((row) => _readerClaimIsLive(row, claim.value))) continue;
      await _deleteReaderClaim(claim.key);
    }
  }

  bool _readerClaimIsLive(Calendar calendar, String? reader) {
    if (calendar.deletedAt != null || !calendar.enabled) return false;
    if (reader == null || reader.isEmpty) return false;
    final owner = calendar.googleAccount;
    if (owner == null) return false;
    if (owner == account) return false;
    final signedIn = signedInAccounts;
    if (signedIn == null) return true;
    if (signedIn.contains(owner)) return false;
    return signedIn.contains(reader);
  }

  Future<void> _deleteReaderClaim(String key) async {
    await (_db.delete(_db.syncState)..where((s) => s.key.equals(key))).go();
    debugPrint('[sync] cleaned stale shared calendar reader');
  }
}
