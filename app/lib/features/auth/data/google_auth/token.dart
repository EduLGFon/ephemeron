part of '../google_auth.dart';

mixin _GoogleAuthToken on _GoogleAuthBase {
  Future<void> ensureTasksScope() async {
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }
    await _ensureInit();
    final account = _activeEmail;
    if (account == null) return;
    var googleAccount = _googleAccountFor(account);
    if (googleAccount == null) {
      googleAccount = await _lightweightAccountFor(account);
      if (googleAccount == null) return;
    }
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
  }

  @override
  Future<String?> accessToken() async {
    final account = _activeEmail;
    if (account == null) return null;
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return _desktopAccessToken(account);
    }
    final cached = _accessTokens[account];
    if (cached != null) {
      final exp = await _storage.googleExpiryMsFor(account);
      // SECURITY: Only the unexpired token stored for this email is reused.
      if (exp != null && DateTime.now().toUtc().millisecondsSinceEpoch < exp) {
        return cached;
      }
    }
    await _ensureInit();
    var googleAccount = _googleAccountFor(account);
    if (googleAccount == null) {
      googleAccount = await _lightweightAccountFor(account);
      if (googleAccount == null) return null;
    }
    // SECURITY: Authorize through the account object bound to this email. The
    // global GoogleSignIn client may belong to another signed-in account.
    final authz = await googleAccount.authorizationClient
        .authorizationForScopes(AppConfig.googleScopes);
    if (authz == null) return null;
    _accessTokens[account] = authz.accessToken;
    await _storage.saveGoogleTokensFor(
      account: account,
      accessToken: authz.accessToken,
      expiryMs: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 50))
          .millisecondsSinceEpoch,
    );
    return _accessTokens[account];
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
