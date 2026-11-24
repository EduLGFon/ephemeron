// Account email identity suite: tokens must only match their own account.
import 'package:ephemeron/features/auth/domain/account_email.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes case and surrounding whitespace', () {
    expect(normalizeAccountEmail('  User@Example.com '), 'user@example.com');
  });

  test('matches the same email case-insensitively', () {
    expect(isSameAccountEmail('User@Example.com', 'user@example.com'), isTrue);
    expect(
      isSameAccountEmail(' user@example.com ', 'USER@EXAMPLE.COM'),
      isTrue,
    );
  });

  test('rejects different accounts', () {
    expect(isSameAccountEmail('a@example.com', 'b@example.com'), isFalse);
  });

  test('never matches empty emails', () {
    expect(isSameAccountEmail('', ''), isFalse);
    expect(isSameAccountEmail('  ', ''), isFalse);
    expect(isSameAccountEmail('a@example.com', ''), isFalse);
  });
}
