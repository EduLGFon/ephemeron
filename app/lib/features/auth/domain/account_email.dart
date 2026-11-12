// Account email identity helpers.
//
// Google account emails are case-insensitive identifiers. Comparing them
// normalized keeps a token bound to the account it was issued for.

/// Returns the canonical form used for account identity comparisons.
String normalizeAccountEmail(String email) => email.trim().toLowerCase();

/// Returns true when both values identify the same account.
///
/// Empty values never match, so a missing email fails closed instead of
/// matching another missing email.
bool isSameAccountEmail(String a, String b) {
  final normalizedA = normalizeAccountEmail(a);
  return normalizedA.isNotEmpty && normalizedA == normalizeAccountEmail(b);
}

/// Returns normalized, de-duplicated account emails in first-seen order.
///
/// Empty and whitespace-only values are dropped so a malformed entry can never
/// surface as a reconnect target.
List<String> normalizeAccountEmails(Iterable<String> emails) {
  final seen = <String>{};
  final result = <String>[];
  for (final email in emails) {
    final normalized = normalizeAccountEmail(email);
    if (normalized.isEmpty || !seen.add(normalized)) continue;
    result.add(normalized);
  }
  return List.unmodifiable(result);
}
