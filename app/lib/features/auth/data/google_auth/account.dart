part of '../google_auth.dart';

mixin _GoogleAuthAccount on _GoogleAuthBase {
  Future<String?>? _restoreInFlight;

  /// Restores stored accounts once, even when the provider build and session
  /// restore both request it during startup.
  Future<String?> restore() {
    return _restoreInFlight ??= _restore().whenComplete(() {
      _restoreInFlight = null;
    });
  }

  Future<String?> _restore() async {
    final accs = await _storage.googleAccounts();
    _setAccountsNeedingReconnect(const []);
    _accounts
      ..clear()
      ..addAll(accs);
    _userIdsByEmail.clear();
    if (_accounts.isEmpty) {
      _activeEmail = null;
      return null;
    }
    // Restoring the stored account list is independent of token acquisition.
    // Keep the current account when it is still stored so a transient token
    // failure can never change the active account.
    final previousActive = _activeEmail;
    if (previousActive == null || !_accounts.contains(previousActive)) {
      _activeEmail = _accounts.first;
    }
    try {
      await _ensureInit();
      // Silent restore only. No lightweight authentication here: on Android
      // it can show the Credential Manager account picker at every launch.
      await _loadUserIds();
      for (final account in _accounts) {
        try {
          // Purely non-interactive. Only a definitive platform denial marks
          // this account for reconnection; transient failures leave the
          // account list and banner state untouched.
          await accessTokenFor(account);
        } catch (_) {
          // One account's plugin/storage failure must not block the others.
        }
      }
    } catch (e) {
      // Log only the type: plugin error text may contain account identifiers.
      // PRIVACY: never interpolate the exception or account data here.
      debugPrint('GoogleAuth.restore token refresh failed: ${e.runtimeType}');
      // Initialization/token acquisition failing is not proof that the stored
      // grants are invalid. Keep the accounts and never raise the reconnect
      // banner from a transient startup failure.
    }
    return _activeEmail;
  }

  Future<void> signOut([String? account]) async {
    final target = account ?? _activeEmail;
    if (target == null) return;
    _clearNeedsReconnect(target);
    _setUserId(target, null);
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      _accessTokens.remove(target);
      _removeGoogleAccount(target);
      _accounts.remove(target);
      await _storage.clearGoogleFor(target);
      final remaining = await _storage.googleAccounts();
      final updated = remaining.where((a) => a != target).toList();
      await _storage.saveGoogleAccounts(updated);
      _accounts
        ..clear()
        ..addAll(updated);
      if (_activeEmail == target) {
        _activeEmail = _accounts.isEmpty ? null : _accounts.first;
      }
      _initialized = false;
      return;
    }
    try {
      await GoogleSignIn.instance.signOut();
    } on UnimplementedError {
      // ignore
    } finally {
      _accessTokens.remove(target);
      _removeGoogleAccount(target);
      _accounts.remove(target);
      await _storage.clearGoogleFor(target);
      final remaining = await _storage.googleAccounts();
      final updated = remaining.where((a) => a != target).toList();
      await _storage.saveGoogleAccounts(updated);
      _accounts
        ..clear()
        ..addAll(updated);
      if (_activeEmail == target) {
        _activeEmail = _accounts.isEmpty ? null : _accounts.first;
      }
      _initialized = false;
    }
  }

  Future<void> handleWebAccount(GoogleSignInAccount account) async {
    await _ensureInit();
    final email = account.email;
    if (!_accounts.contains(email)) _accounts.add(email);
    _storeGoogleAccount(account);
    _activeEmail = email;
    final authz = await account.authorizationClient.authorizeScopes(
      AppConfig.googleScopes,
    );
    final token = authz.accessToken;
    _accessTokens[email] = token;
    final userId = account.id;
    if (userId.isNotEmpty) {
      _setUserId(email, userId);
      await _storage.saveGoogleUserIdFor(account: email, userId: userId);
    }
    await _storage.saveGoogleEmail(email);
    await _storage.saveGoogleTokensFor(
      account: email,
      accessToken: token,
      expiryMs: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 50))
          .millisecondsSinceEpoch,
    );
    _clearNeedsReconnect(email);
    await _storage.saveGoogleAccounts(_accounts);
  }
}
