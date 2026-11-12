// Pure policy helpers for Google access tokens cached in secure storage.

/// Returns true when [accessToken] may be used at [now].
///
/// A token without a future expiry is never usable: its validity cannot be
/// established, so callers must reacquire it.
///
/// SECURITY: This check binds reuse to the expiry stored for the same account.
/// Callers must resolve the token through that account's storage key.
bool isGoogleAccessTokenUsable({
  required String? accessToken,
  required int? expiryMs,
  required DateTime now,
}) {
  if (accessToken == null || accessToken.isEmpty || expiryMs == null) {
    return false;
  }
  return expiryMs > now.toUtc().millisecondsSinceEpoch;
}
