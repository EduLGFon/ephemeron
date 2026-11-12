// Google restore suite: cached token usability and reconnect identity.
//
// The GoogleSignIn plugin is not available in unit tests, so restore itself is
// covered through the pure helpers it uses.
import 'package:ephemeron/features/auth/domain/account_email.dart';
import 'package:ephemeron/features/auth/domain/google_token_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 12, 12);

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
}
