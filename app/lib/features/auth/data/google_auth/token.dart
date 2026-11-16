part of '../google_auth.dart';

mixin _GoogleAuthToken on _GoogleAuthBase {
  /// Requests Calendar/Tasks scopes interactively for the active account.
  ///
  /// Only works while the account object from an interactive sign-in is still
  /// in memory. After a restart the reconnect flow (`signIn`) is used instead.
  Future<void> ensureTasksScope() async {
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }
    await _ensureInit();
    final account = _activeEmail;
    if (account == null) return;
    final googleAccount = _googleAccountFor(account);
    // This is only reachable from an explicit user action, and it needs a live
    // account object to request new scopes interactively. After a restart
    // there is no such object until the user signs in again.
    if (googleAccount == null) return;
    // SECURITY: Authorize through the account object bound to the active
    // email. The global client may belong to another signed-in account.
    final authz = await googleAccount.authorizationClient.authorizeScopes(
      AppConfig.googleScopes,
    );
    final token = authz.accessToken;
    _accessTokens[account] = token;
    await _storage.saveGoogleTokensFor(
      account: account,
      accessToken: token,
      expiryMs: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 50))
          .millisecondsSinceEpoch,
    );
    final userId = googleAccount.id;
    if (userId.isNotEmpty) {
      _setUserId(account, userId);
      await _storage.saveGoogleUserIdFor(account: account, userId: userId);
    }
    _clearNeedsReconnect(account);
  }

  @override
  Future<String?> accessToken() async {
    final account = _activeEmail;
    if (account == null) return null;
    return accessTokenFor(account);
  }

  /// Returns an access token bound to [account].
  ///
  /// After a process restart this restores any unexpired token cached for the
  /// account, not only the active one. When no valid token exists it tries the
  /// in-memory account authorization, then a silent platform request bound to
  /// this account. It never prompts.
  @override
  Future<String?> accessTokenFor(String account) async {
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return _desktopAccessToken(account);
    }
    final now = DateTime.now().toUtc();
    final cached = _accessTokens[account];
    final cachedExpiry = await _storage.googleExpiryMsFor(account);
    // SECURITY: Only the unexpired token stored for this exact account is
    // reused. A cached token without a trusted expiry is never returned.
    if (isGoogleAccessTokenUsable(
      accessToken: cached,
      expiryMs: cachedExpiry,
      now: now,
    )) {
      _clearNeedsReconnect(account);
      return cached;
    }
    final stored = await _storage.googleAccessTokenFor(account);
    final storedExpiry = await _storage.googleExpiryMsFor(account);
    // SECURITY: The per-account storage key binds this token to the email it
    // was issued for, so an unexpired stored token is safe to restore.
    if (isGoogleAccessTokenUsable(
      accessToken: stored,
      expiryMs: storedExpiry,
      now: now,
    )) {
      _accessTokens[account] = stored!;
      _clearNeedsReconnect(account);
      return stored;
    }
    await _ensureInit();
    final googleAccount = _googleAccountFor(account);
    if (googleAccount != null) {
      try {
        final authz = await googleAccount.authorizationClient
            .authorizationForScopes(AppConfig.googleScopes);
        if (authz != null) {
          await _cacheToken(account, authz.accessToken);
          return authz.accessToken;
        }
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.userMismatch) {
          _markNeedsReconnect(account);
        }
        // Otherwise fall through to the account-bound silent request below.
      } catch (_) {
        // Fall through to the account-bound silent request below.
      }
    }
    // SECURITY: The silent request is bound to this account's email/user id.
    // It never uses the global GoogleSignIn client, which may belong to
    // another signed-in account.
    final silent = await _authorizeSilently(account);
    switch (silent.status) {
      case _SilentAuthStatus.token:
        final token = silent.token!;
        await _cacheToken(account, token);
        return token;
      case _SilentAuthStatus.unauthorized:
        _markNeedsReconnect(account);
        return null;
      case _SilentAuthStatus.unavailable:
        // Transient: keep the account and any existing banner state, and let
        // the next sync retry.
        return null;
    }
  }

  /// Forgets a token that Google rejected (an HTTP 401/403 auth response).
  ///
  /// SECURITY: Only the cached access token and expiry for this exact account
  /// are cleared. The account entry, refresh token, user id, and every other
  /// account stay untouched, so a rejected token can never disconnect an
  /// account. The platform cache is cleared too when available.
  Future<void> invalidateAccessTokenFor(String account) async {
    final cached = _accessTokens.remove(account);
    String? token = cached;
    try {
      token ??= await _storage.googleAccessTokenFor(account);
      await _storage.clearGoogleAccessTokenFor(account);
    } catch (_) {
      // Storage unavailable: the in-memory token was still dropped.
    }
    if (token == null || token.isEmpty) return;
    try {
      await GoogleSignInPlatform.instance.clearAuthorizationToken(
        ClearAuthorizationTokenParams(accessToken: token),
      );
    } catch (_) {
      // Best effort: web/desktop/test platforms may not implement it.
    }
  }

  Future<void> _cacheToken(String account, String token) async {
    _accessTokens[account] = token;
    await _storage.saveGoogleTokensFor(
      account: account,
      accessToken: token,
      expiryMs: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 50))
          .millisecondsSinceEpoch,
    );
    _clearNeedsReconnect(account);
  }

  /// Desktop keeps its stored refresh-token path; there is no GoogleSignIn
  /// plugin account object on Linux or Windows.
  Future<String?> _desktopAccessToken(String account) async {
    final cached = _accessTokens[account];
    if (cached != null) {
      final exp = await _storage.googleExpiryMsFor(account);
      if (exp == null || DateTime.now().toUtc().millisecondsSinceEpoch < exp) {
        return cached;
      }
    }
    await _ensureInit();
    final storedAccess = await _storage.googleAccessTokenFor(account);
    final exp = await _storage.googleExpiryMsFor(account);
    if (storedAccess != null &&
        (exp == null || DateTime.now().toUtc().millisecondsSinceEpoch < exp)) {
      _accessTokens[account] = storedAccess;
      return storedAccess;
    }
    final refresh = await _storage.googleRefreshTokenFor(account);
    if (refresh == null || AppConfig.linuxGoogleClientSecret.isEmpty) {
      return null;
    }
    final res = await HttpClient()
        .postUrl(Uri.parse('https://oauth2.googleapis.com/token'))
        .then((r) async {
          r.headers.contentType = ContentType(
            'application',
            'x-www-form-urlencoded',
          );
          final body =
              'client_id=${Uri.encodeQueryComponent(AppConfig.linuxGoogleClientId)}'
              '&client_secret=${Uri.encodeQueryComponent(AppConfig.linuxGoogleClientSecret)}'
              '&refresh_token=${Uri.encodeQueryComponent(refresh)}'
              '&grant_type=refresh_token';
          r.write(body);
          return r.close();
        });
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) return null;
    final json = jsonDecode(body) as Map<String, dynamic>;
    final newAccess = json['access_token'] as String?;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    if (newAccess != null) {
      _accessTokens[account] = newAccess;
      await _storage.saveGoogleTokensFor(
        account: account,
        accessToken: newAccess,
        expiryMs: DateTime.now()
            .toUtc()
            .add(Duration(seconds: expiresIn - 60))
            .millisecondsSinceEpoch,
      );
    }
    return _accessTokens[account];
  }
}
