// Google restore suite: cached token usability, reconnect identity, and the
// silent per-account restore path.
//
// The GoogleSignIn plugin is not available in unit tests. GoogleAuth accepts
// injected platform initialization and silent authorization so restore can be
// exercised without the plugin or any UI.
import 'package:ephemeron/core/config/app_config.dart';
import 'package:ephemeron/core/config/safe_storage.dart';
import 'package:ephemeron/features/auth/data/google_auth.dart';
import 'package:ephemeron/features/auth/domain/account_email.dart';
import 'package:ephemeron/features/auth/domain/google_token_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

void main() {
  final now = DateTime.utc(2026, 11, 12, 12);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    // The mobile token path is the one that used to prompt.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('accepts an unexpired stored access token', () {
    expect(
      isGoogleAccessTokenUsable(
        accessToken: 'token',
        expiryMs: now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
        now: now,
      ),
      isTrue,
    );
  });

  test('rejects an expired stored access token', () {
    expect(
      isGoogleAccessTokenUsable(
        accessToken: 'token',
        expiryMs: now
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        now: now,
      ),
      isFalse,
    );
  });

  test('rejects a stored access token without expiry', () {
    expect(
      isGoogleAccessTokenUsable(accessToken: 'token', expiryMs: null, now: now),
      isFalse,
    );
  });

  test('rejects an empty access token even when unexpired', () {
    expect(
      isGoogleAccessTokenUsable(
        accessToken: '',
        expiryMs: now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
        now: now,
      ),
      isFalse,
    );
  });

  test('normalizes and de-duplicates reconnect accounts', () {
    expect(
      normalizeAccountEmails([
        ' User@Example.com ',
        'user@example.com',
        'B@Example.com',
        '',
        '   ',
      ]),
      ['user@example.com', 'b@example.com'],
    );
  });

  test('reconnect accounts cannot be mutated by callers', () {
    final accounts = normalizeAccountEmails(['a@example.com']);
    expect(() => accounts.add('b@example.com'), throwsUnsupportedError);
  });

  test('restore refreshes every account silently without prompting', () async {
    final storage = SafeSecureStorage();
    await storage.saveGoogleAccounts(['a@example.com', 'b@example.com']);
    await storage.saveGoogleUserIdFor(
      account: 'a@example.com',
      userId: 'user-a',
    );
    await storage.saveGoogleUserIdFor(
      account: 'b@example.com',
      userId: 'user-b',
    );
    final requests = <AuthorizationRequestDetails>[];
    final auth = GoogleAuth(
      storage: storage,
      initializePlatform: () async {},
      silentAuthorizer: (request) async {
        requests.add(request);
        return 'token-${request.email}';
      },
    );

    expect(await auth.restore(), 'a@example.com');
    expect(auth.accounts, ['a@example.com', 'b@example.com']);
    expect(auth.accountsNeedingReconnect, isEmpty);
    expect(requests, hasLength(2));
    expect(requests.every((r) => !r.promptIfUnauthorized), isTrue);
    expect(requests.map((r) => r.email), ['a@example.com', 'b@example.com']);
    expect(requests.map((r) => r.userId), ['user-a', 'user-b']);
    expect(requests.first.scopes, AppConfig.googleScopes);
    expect(
      await storage.googleAccessTokenFor('b@example.com'),
      'token-b@example.com',
    );
  });

  test('restore marks only the account whose silent grant fails', () async {
    final storage = SafeSecureStorage();
    await storage.saveGoogleAccounts(['a@example.com', 'b@example.com']);
    final auth = GoogleAuth(
      storage: storage,
      initializePlatform: () async {},
      silentAuthorizer: (request) async =>
          isSameAccountEmail(request.email ?? '', 'a@example.com')
          ? 'token-a'
          : null,
    );

    await auth.restore();
    expect(auth.accountsNeedingReconnect, ['b@example.com']);
  });

  test('silent authorization falls back to email without a user id', () async {
    final storage = SafeSecureStorage();
    await storage.saveGoogleAccounts(['legacy@example.com']);
    final requests = <AuthorizationRequestDetails>[];
    final auth = GoogleAuth(
      storage: storage,
      initializePlatform: () async {},
      silentAuthorizer: (request) async {
        requests.add(request);
        return 'token';
      },
    );

    await auth.restore();
    expect(requests.single.userId, 'legacy@example.com');
    expect(requests.single.promptIfUnauthorized, isFalse);
  });

  test(
    'google user id is stored beside the account and cleared with it',
    () async {
      final storage = SafeSecureStorage();
      await storage.saveGoogleUserIdFor(
        account: 'a@example.com',
        userId: 'user-a',
      );
      expect(await storage.googleUserIdFor('a@example.com'), 'user-a');
      await storage.clearGoogleFor('a@example.com');
      expect(await storage.googleUserIdFor('a@example.com'), isNull);
    },
  );

  test('empty google user id is never written', () async {
    final storage = SafeSecureStorage();
    await storage.saveGoogleUserIdFor(account: 'a@example.com', userId: '');
    expect(await storage.googleUserIdFor('a@example.com'), isNull);
  });
}
