part of '../google_auth.dart';

abstract class _GoogleAuthBase {
  _GoogleAuthBase({
    SafeSecureStorage? storage,
    this.silentAuthorizer,
    this.initializePlatform,
  }) : _storage = storage ?? SafeSecureStorage();

  final SafeSecureStorage _storage;

  /// Test hook: replaces the platform silent-authorization call.
  final Future<String?> Function(AuthorizationRequestDetails request)?
  silentAuthorizer;

  /// Test hook: replaces plugin initialization.
  final Future<void> Function()? initializePlatform;

  bool _initialized = false;

  Future<void> _ensureInit();
  Future<String?> accessToken();
  Future<String?> accessTokenFor(String account);
  final List<String> _accounts = [];
  String? _activeEmail;
  final Map<String, String?> _accessTokens = {};
  final List<String> _accountsNeedingReconnect = [];

  /// Google user id per normalized email. Android authorizes by email, but
  /// iOS needs the user id for a silent keychain refresh.
  final Map<String, String?> _userIdsByEmail = {};

  /// Normalized, de-duplicated emails that could not restore a token and need
  /// interactive reconnection.
  List<String> get accountsNeedingReconnect =>
      List.unmodifiable(_accountsNeedingReconnect);

  void _setAccountsNeedingReconnect(Iterable<String> emails) {
    _accountsNeedingReconnect
      ..clear()
      ..addAll(normalizeAccountEmails(emails));
  }

  void _clearNeedsReconnect(String email) {
    _accountsNeedingReconnect.removeWhere((a) => isSameAccountEmail(a, email));
  }

  // Signed-in account objects keyed by normalized email. Tokens must come from
  // the matching account's authorization client, never the global one.
  final Map<String, GoogleSignInAccount> _googleAccountsByEmail = {};

  GoogleSignInAccount? _googleAccountFor(String email) {
    final normalized = normalizeAccountEmail(email);
    if (normalized.isEmpty) return null;
    final account = _googleAccountsByEmail[normalized];
    if (account == null) return null;
    // SECURITY: A token may only be used for the email it was issued for.
    return isSameAccountEmail(account.email, email) ? account : null;
  }

  void _storeGoogleAccount(GoogleSignInAccount account) {
    final normalized = normalizeAccountEmail(account.email);
    if (normalized.isEmpty) return;
    _googleAccountsByEmail[normalized] = account;
  }

  void _removeGoogleAccount(String email) {
    final normalized = normalizeAccountEmail(email);
    if (normalized.isNotEmpty) _googleAccountsByEmail.remove(normalized);
  }

  Future<void> _loadUserIds() async {
    _userIdsByEmail.clear();
    for (final account in _accounts) {
      final userId = await _storage.googleUserIdFor(account);
      if (userId != null && userId.isNotEmpty) {
        _userIdsByEmail[normalizeAccountEmail(account)] = userId;
      }
    }
  }

  void _setUserId(String account, String? userId) {
    final normalized = normalizeAccountEmail(account);
    if (normalized.isEmpty) return;
    if (userId == null || userId.isEmpty) {
      _userIdsByEmail.remove(normalized);
    } else {
      _userIdsByEmail[normalized] = userId;
    }
  }

  String? _userIdFor(String account) =>
      _userIdsByEmail[normalizeAccountEmail(account)];

  /// One non-interactive authorization attempt for [account].
  ///
  /// SECURITY: [AuthorizationRequestDetails.promptIfUnauthorized] is always
  /// false, so the platform can never show an account picker or consent
  /// screen. The request is bound to the stored account email/user id, so the
  /// returned token is never used for another account.
  Future<String?> _authorizeSilently(String account) async {
    // Web cannot guarantee a silent token after a reload; never trigger a
    // FedCM or popup from startup.
    if (kIsWeb) return null;
    final request = AuthorizationRequestDetails(
      scopes: AppConfig.googleScopes,
      // Android authorizes by email and ignores userId. iOS refreshes by
      // userId. The email fallback keeps Android silent for legacy accounts
      // that predate stored user ids.
      userId: _userIdFor(account) ?? account,
      email: account,
      promptIfUnauthorized: false,
    );
    try {
      final injected = silentAuthorizer;
      if (injected != null) return await injected(request);
      // Bounded so a slow Play Services call cannot hold session restore.
      final data = await GoogleSignInPlatform.instance
          .clientAuthorizationTokensForScopes(
            ClientAuthorizationTokensForScopesParameters(request: request),
          )
          .timeout(const Duration(seconds: 10));
      final token = data?.accessToken;
      return token == null || token.isEmpty ? null : token;
    } catch (_) {
      // A revoked grant or a platform failure is a reconnect signal. Never
      // log plugin error text: it may contain account identifiers.
      return null;
    }
  }

  List<String> get accounts => List.unmodifiable(_accounts);
  String? get email => _activeEmail;
  bool get isSignedIn => _activeEmail != null && _accounts.isNotEmpty;

  Future<void> setActiveAccount(String email) async {
    if (_accounts.contains(email)) _activeEmail = email;
  }

  List<String> _scopes(bool tasks) =>
      tasks ? AppConfig.googleScopes : [AppConfig.googleScopes.first];

  String _randomString(int length) {
    final rand = Random.secure();
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }
}
