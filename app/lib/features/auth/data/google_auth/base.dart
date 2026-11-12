part of '../google_auth.dart';

abstract class _GoogleAuthBase {
  _GoogleAuthBase({SafeSecureStorage? storage})
    : _storage = storage ?? SafeSecureStorage();

  final SafeSecureStorage _storage;
  bool _initialized = false;

  Future<void> _ensureInit();
  Future<String?> accessToken();
  final List<String> _accounts = [];
  String? _activeEmail;
  final Map<String, String?> _accessTokens = {};

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

  /// One lightweight sign-in attempt, or null when unavailable.
  Future<GoogleSignInAccount?> _attemptLightweightAccount() async {
    try {
      final future = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (future == null) return null;
      return await future;
    } catch (_) {
      return null;
    }
  }

  /// Returns a lightweight account only when it is the requested account.
  Future<GoogleSignInAccount?> _lightweightAccountFor(String email) async {
    final result = await _attemptLightweightAccount();
    if (result == null) return null;
    // SECURITY: Reject an account that does not match the requested email.
    // Using its token here would fetch one account's data with another's token.
    if (!isSameAccountEmail(result.email, email)) return null;
    _storeGoogleAccount(result);
    return result;
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
