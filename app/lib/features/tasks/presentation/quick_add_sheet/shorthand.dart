part of '../quick_add_sheet.dart';

final _tokenBoundary = RegExp(r'\s+');

RegExp _tokenPattern(String token) => RegExp(
  r'(?<![\p{L}\p{N}_-])' + RegExp.escape(token) + r'(?![\p{L}\p{N}_-])',
  unicode: true,
  caseSensitive: false,
);

bool _hasToken(String text, String token) =>
    _tokenPattern(token).hasMatch(text);

/// Emits the shorthand form for [name], quoting names that contain spaces.
String quickAddListToken(String name) =>
    name.contains(RegExp(r'\s')) ? '~"$name"' : '~$name';

/// Emits the shorthand form for [name], quoting names that contain spaces.
String quickAddTagToken(String name) =>
    name.contains(RegExp(r'\s')) ? '#"$name"' : '#$name';

/// Appends [token] once, separated by a single space.
String appendQuickAddShorthand(String text, String token) {
  final trimmed = text.trimRight();
  if (_hasToken(trimmed, token)) return trimmed;
  return trimmed.isEmpty ? token : '$trimmed $token';
}

/// Adds [token] when absent or removes it when already present.
String toggleQuickAddShorthand(String text, String token) {
  final pattern = _tokenPattern(token);
  if (!pattern.hasMatch(text)) return appendQuickAddShorthand(text, token);
  return text.replaceAll(pattern, ' ').replaceAll(_tokenBoundary, ' ').trim();
}

/// User-facing repeat label. RRULEs are never shown raw in the preview.
String quickAddRepeatLabel(String rrule) {
  final freq = RegExp(r'FREQ=([A-Z]+)').firstMatch(rrule)?.group(1);
  if (freq == null) return 'Repeats';
  switch (freq) {
    case 'DAILY':
      return 'Daily';
    case 'WEEKLY':
      final byDay = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rrule)?.group(1);
      if (byDay == null) return 'Weekly';
      return 'Weekly on ${_weekdayNames(byDay)}';
    case 'MONTHLY':
      return 'Monthly';
    case 'YEARLY':
      return 'Yearly';
    default:
      return 'Custom repeat';
  }
}

String _weekdayNames(String codes) {
  const names = {
    'MO': 'Mon',
    'TU': 'Tue',
    'WE': 'Wed',
    'TH': 'Thu',
    'FR': 'Fri',
    'SA': 'Sat',
    'SU': 'Sun',
  };
  final labels = [for (final code in codes.split(',')) names[code] ?? code];
  return labels.join(', ');
}
