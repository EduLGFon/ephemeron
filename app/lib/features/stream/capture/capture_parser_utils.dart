part of 'capture_parser.dart';

final RegExp _tokRe = RegExp(r'\S+');
final RegExp _colonTimeRe = RegExp(r'^(\d{1,2}):(\d{2})$');
final RegExp _hTimeRe = RegExp(r'^(\d{1,2})h(\d{2})?$');
final RegExp _ampmTimeRe = RegExp(r'^(\d{1,2})(am|pm)$');

final RegExp _wsRe = RegExp(r'\s+');

List<_Tok> _tokenize(String s) {
  final res = <_Tok>[];
  for (final m in _tokRe.allMatches(s)) {
    res.add(_Tok(m.group(0)!, m.start, m.end));
  }
  return res;
}

(int, int)? _parseTime(String raw) {
  final s = raw.toLowerCase();
  var m = _colonTimeRe.firstMatch(s);
  if (m != null) {
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h <= 23 && min <= 59) return (h, min);
  }
  m = _hTimeRe.firstMatch(s);
  if (m != null) {
    final h = int.parse(m.group(1)!);
    final min = m.group(2) != null ? int.parse(m.group(2)!) : 0;
    if (h <= 23 && min <= 59) return (h, min);
  }
  m = _ampmTimeRe.firstMatch(s);
  if (m != null) {
    var h = int.parse(m.group(1)!);
    final ap = m.group(2)!;
    if (ap == 'pm' && h < 12) h += 12;
    if (ap == 'am' && h == 12) h = 0;
    if (h <= 23) return (h, 0);
  }
  return null;
}

DateTime? _resolveDate(DateTime now, int day, int month) {
  if (day < 1 || day > 31 || month < 1 || month > 12) return null;
  // Validate the day actually exists in the month (no rollover).
  DateTime candidate;
  try {
    candidate = DateTime(now.year, month, day);
  } catch (_) {
    return null;
  }
  if (candidate.month != month || candidate.day != day) return null;
  var d = candidate;
  final today = DateTime(now.year, now.month, now.day);
  if (d.isBefore(today)) {
    final next = DateTime(now.year + 1, month, day);
    if (next.month != month || next.day != day) return null;
    d = next;
  }
  return d;
}

DateTime _nextWeekdayOnOrAfter(DateTime now, int wd) {
  var d = DateTime(now.year, now.month, now.day);
  while (d.weekday != wd) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

DateTime _nextWeekdayAfter(DateTime now, int wd) {
  var d = DateTime(now.year, now.month, now.day);
  do {
    d = d.add(const Duration(days: 1));
  } while (d.weekday != wd);
  return d;
}
