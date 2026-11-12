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
