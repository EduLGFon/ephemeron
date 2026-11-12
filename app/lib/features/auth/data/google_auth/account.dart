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
    if (_accounts.isEmpty) return null;
    _activeEmail = _accounts.first;
    try {
      await _ensureInit();
      // One lightweight attempt for the whole restore. Its account is stored
      // only when it is one of the emails already known locally.
      final lightweight = await _attemptLightweightAccount();
      if (lightweight != null &&
          _accounts.any((a) => isSameAccountEmail(a, lightweight.email))) {
        _storeGoogleAccount(lightweight);
      }
      final needsReconnect = <String>[];
      for (final account in _accounts) {
        String? token;
        try {
          token = await accessTokenFor(account);
        } catch (_) {
          // One account's plugin failure must not block the others.
          token = null;
        }
        if (token == null) needsReconnect.add(account);
      }
      _setAccountsNeedingReconnect(needsReconnect);
      debugPrint('GoogleAuth.restore ok');
      return _activeEmail;
    } catch (e) {
      // Log only the type: plugin error text may contain account identifiers.
      debugPrint('GoogleAuth.restore failed: ${e.runtimeType}');
      // A failed outer restore cannot prove any account is usable. Warn for
      // every stored account instead of failing silently.
      if (_accounts.isNotEmpty) _setAccountsNeedingReconnect(_accounts);
      return _activeEmail;
    }
  }

  Future<void> signOut([String? account]) async {
    final target = account ?? _activeEmail;
    if (target == null) return;
    _clearNeedsReconnect(target);
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
