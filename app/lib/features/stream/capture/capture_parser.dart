// Pure, deterministic, offline capture parser. No Flutter imports.
import 'capture_kind.dart';
import 'capture_priority.dart';
import 'capture_repeat.dart';
import 'capture_span.dart';
import 'capture_vocabulary.dart';

export 'capture_vocabulary.dart' show CaptureLocale;

class CaptureDraft {
  const CaptureDraft({
    required this.kind,
    required this.title,
    this.date,
    this.startTime,
    this.endTime,
    this.repeat,
    this.listTag,
    this.priority = CapturePriority.none,
    this.spans = const <CaptureSpan>[],
  });

  final CaptureKind kind;
  final String title;
  final DateTime? date;
  final DateTime? startTime;
  final DateTime? endTime;
  final CaptureRepeat? repeat;
  final String? listTag;
  final CapturePriority priority;
  final List<CaptureSpan> spans;

  @override
  bool operator ==(Object other) =>
      other is CaptureDraft &&
      kind == other.kind &&
      title == other.title &&
      date == other.date &&
      startTime == other.startTime &&
      endTime == other.endTime &&
      repeat == other.repeat &&
      listTag == other.listTag &&
      priority == other.priority &&
      _spansEqual(spans, other.spans);

  @override
  int get hashCode => Object.hash(
    kind,
    title,
    date,
    startTime,
    endTime,
    repeat,
    listTag,
    priority,
    Object.hashAll(spans),
  );

  static bool _spansEqual(List<CaptureSpan> a, List<CaptureSpan> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _Tok {
  _Tok(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

final RegExp _tokRe = RegExp(r'\S+');
final RegExp _colonTimeRe = RegExp(r'^(\d{1,2}):(\d{2})$');
final RegExp _hTimeRe = RegExp(r'^(\d{1,2})h(\d{2})?$');
final RegExp _ampmTimeRe = RegExp(r'^(\d{1,2})(am|pm)$');

CaptureDraft parseCapture(
  String input, {
  required CaptureLocale locale,
  DateTime? now,
  DateTime Function()? clock,
}) {
  final resolvedNow = clock?.call() ?? now ?? DateTime.now();
  final tokens = _tokenize(input);
  final n = tokens.length;
  final used = List<bool>.filled(n, false);
  final spans = <CaptureSpan>[];

  CaptureKind kind = CaptureKind.task;
  bool prefixSet = false;
  CaptureRepeat? repeat;
  String? listTag;
  CapturePriority priority = CapturePriority.none;
  DateTime? dateResolved;
  int? startHour;
  int? startMinute;
  int? endHour;
  int? endMinute;
  bool countdown = false;

  // Power-user prefix.
  if (n > 1) {
    final first = tokens[0].text.toLowerCase();
    CaptureKind? pk;
    if (first == 't') pk = CaptureKind.task;
    if (first == 'e') pk = CaptureKind.event;
    if (first == 'h') pk = CaptureKind.habit;
    if (first == 'c') pk = CaptureKind.countdown;
    if (pk != null) {
      kind = pk;
      prefixSet = true;
      used[0] = true;
      spans.add(
        CaptureSpan(kind: 'type', start: tokens[0].start, end: tokens[0].end),
      );
    }
  }

  // Tags and priorities anywhere.
  for (var i = 0; i < n; i++) {
    if (used[i]) continue;
    final t = tokens[i].text;
    if (t.startsWith('#') && t.length > 1) {
      listTag ??= t.substring(1);
      used[i] = true;
      spans.add(
        CaptureSpan(kind: 'tag', start: tokens[i].start, end: tokens[i].end),
      );
    } else if (t.startsWith('!') && t.length > 1) {
      final w = t.substring(1).toLowerCase();
      final p = priorityWords[w];
      if (p != null) priority = p;
      used[i] = true;
      spans.add(
        CaptureSpan(
          kind: 'priority',
          start: tokens[i].start,
          end: tokens[i].end,
        ),
      );
    }
  }

  // Countdown keywords.
  for (var i = 0; i < n; i++) {
    if (used[i]) continue;
    final w = tokens[i].text.toLowerCase();
    if (countdownWords[locale]!.contains(w)) {
      if (!prefixSet) {
        kind = CaptureKind.countdown;
        countdown = true;
      }
      used[i] = true;
      spans.add(
        CaptureSpan(kind: 'type', start: tokens[i].start, end: tokens[i].end),
      );
    }
  }

  // Repeat rules.
  for (var i = 0; i < n; i++) {
    if (used[i]) continue;
    final w = tokens[i].text.toLowerCase();
    if (dailyWords[locale]!.contains(w)) {
      repeat = const CaptureRepeat(frequency: CaptureRepeatFrequency.daily);
      used[i] = true;
      spans.add(
        CaptureSpan(kind: 'repeat', start: tokens[i].start, end: tokens[i].end),
      );
      continue;
    }
    if (repeatStartWords[locale]!.contains(w)) {
      // daily phrase?
      if (i + 1 < n &&
          !used[i + 1] &&
          dayWords[locale]!.contains(tokens[i + 1].text.toLowerCase())) {
        repeat = const CaptureRepeat(frequency: CaptureRepeatFrequency.daily);
        used[i] = true;
        used[i + 1] = true;
        spans.add(
          CaptureSpan(
            kind: 'repeat',
            start: tokens[i].start,
            end: tokens[i + 1].end,
          ),
        );
        continue;
      }
      // collect weekdays
      var j = i + 1;
      final wds = <int>[];
      while (j < n && !used[j]) {
        final wd = weekdays[locale]![tokens[j].text.toLowerCase()];
        if (wd == null) break;
        wds.add(wd);
        j++;
      }
      if (wds.isNotEmpty) {
        repeat = CaptureRepeat(
          frequency: CaptureRepeatFrequency.weekly,
          weekdays: wds,
        );
        for (var k = i; k < j; k++) {
          used[k] = true;
        }
        spans.add(
          CaptureSpan(
            kind: 'repeat',
            start: tokens[i].start,
            end: tokens[j - 1].end,
          ),
        );
        i = j - 1;
      }
    }
  }

  // Date / time / relative scanning.
  for (var i = 0; i < n; i++) {
    if (used[i]) continue;
    final w = tokens[i].text.toLowerCase();

    // today
    if (todayWords[locale]!.contains(w)) {
      dateResolved = DateTime(
        resolvedNow.year,
        resolvedNow.month,
        resolvedNow.day,
      );
      used[i] = true;
      spans.add(
        CaptureSpan(kind: 'date', start: tokens[i].start, end: tokens[i].end),
      );
      continue;
    }
    // tomorrow
    if (tomorrowWords[locale]!.contains(w)) {
      final d = DateTime(
        resolvedNow.year,
        resolvedNow.month,
        resolvedNow.day,
      ).add(const Duration(days: 1));
      dateResolved = d;
      used[i] = true;
      spans.add(
        CaptureSpan(kind: 'date', start: tokens[i].start, end: tokens[i].end),
      );
      continue;
    }
    // next weekday
    if (nextWords[locale]!.contains(w) && i + 1 < n && !used[i + 1]) {
      final wd = weekdays[locale]![tokens[i + 1].text.toLowerCase()];
      if (wd != null) {
        dateResolved = _nextWeekdayAfter(resolvedNow, wd, strict: true);
        used[i] = true;
        used[i + 1] = true;
        spans.add(
          CaptureSpan(
            kind: 'date',
            start: tokens[i].start,
            end: tokens[i + 1].end,
          ),
        );
        i++;
        continue;
      }
    }
    // in X days/hours
    if (inWords[locale]!.contains(w) &&
        i + 2 < n &&
        !used[i + 1] &&
        !used[i + 2]) {
      final num = int.tryParse(tokens[i + 1].text);
      final dw = tokens[i + 2].text.toLowerCase();
      if (num != null && dayWords[locale]!.contains(dw)) {
        dateResolved = DateTime(
          resolvedNow.year,
          resolvedNow.month,
          resolvedNow.day,
        ).add(Duration(days: num));
        used[i] = true;
        used[i + 1] = true;
        used[i + 2] = true;
        spans.add(
          CaptureSpan(
            kind: 'date',
            start: tokens[i].start,
            end: tokens[i + 2].end,
          ),
        );
        i += 2;
        continue;
      }
      if (num != null && hourWords[locale]!.contains(dw)) {
        final dt = resolvedNow.add(Duration(hours: num));
        dateResolved = DateTime(dt.year, dt.month, dt.day);
        startHour = dt.hour;
        startMinute = dt.minute;
        used[i] = true;
        used[i + 1] = true;
        used[i + 2] = true;
        spans.add(
          CaptureSpan(
            kind: 'time',
            start: tokens[i].start,
            end: tokens[i + 2].end,
          ),
        );
        i += 2;
        continue;
      }
    }
    // day month
    final dayNum = int.tryParse(tokens[i].text);
    if (dayNum != null && i + 1 < n && !used[i + 1]) {
      final m = months[locale]![tokens[i + 1].text.toLowerCase()];
      if (m != null) {
        dateResolved = _resolveDate(resolvedNow, dayNum, m);
        used[i] = true;
        used[i + 1] = true;
        spans.add(
          CaptureSpan(
            kind: 'date',
            start: tokens[i].start,
            end: tokens[i + 1].end,
          ),
        );
        i++;
        continue;
      }
    }
    // month day
    if (months[locale]!.containsKey(w) && i + 1 < n && !used[i + 1]) {
      final dayNum2 = int.tryParse(tokens[i + 1].text);
      if (dayNum2 != null) {
        dateResolved = _resolveDate(resolvedNow, dayNum2, months[locale]![w]!);
        used[i] = true;
        used[i + 1] = true;
        spans.add(
          CaptureSpan(
            kind: 'date',
            start: tokens[i].start,
            end: tokens[i + 1].end,
          ),
        );
        i++;
        continue;
      }
    }
    // standalone weekday as date
    final wd = weekdays[locale]![w];
    if (wd != null) {
      dateResolved = _nextWeekdayOnOrAfter(resolvedNow, wd);
      used[i] = true;
      spans.add(
        CaptureSpan(kind: 'date', start: tokens[i].start, end: tokens[i].end),
      );
      continue;
    }

    // time range single token
    if (tokens[i].text.contains('-')) {
      final parts = tokens[i].text.split('-');
      if (parts.length == 2) {
        final a = _parseTime(parts[0]);
        final b = _parseTime(parts[1]);
        if (a != null && b != null) {
          startHour = a.$1;
          startMinute = a.$2;
          endHour = b.$1;
          endMinute = b.$2;
          used[i] = true;
          spans.add(
            CaptureSpan(
              kind: 'time',
              start: tokens[i].start,
              end: tokens[i].end,
            ),
          );
          continue;
        }
      }
    }
    // time token
    final tm = _parseTime(tokens[i].text);
    if (tm != null) {
      // range with following - time?
      if (i + 2 < n &&
          !used[i + 1] &&
          tokens[i + 1].text == '-' &&
          !used[i + 2]) {
        final tm2 = _parseTime(tokens[i + 2].text);
        if (tm2 != null) {
          startHour = tm.$1;
          startMinute = tm.$2;
          endHour = tm2.$1;
          endMinute = tm2.$2;
          used[i] = true;
          used[i + 1] = true;
          used[i + 2] = true;
          spans.add(
            CaptureSpan(
              kind: 'time',
              start: tokens[i].start,
              end: tokens[i + 2].end,
            ),
          );
          i += 2;
          continue;
        }
      }
      // am/pm split not handled here (handled below), but _parseTime covers attached
      if (startHour == null) {
        startHour = tm.$1;
        startMinute = tm.$2;
      } else if (endHour == null) {
        endHour = tm.$1;
        endMinute = tm.$2;
      } else {
        // extra time stays in title
      }
      // If this time is followed by am/pm? already attached; if next token is am/pm and _parseTime failed? handle below.
      used[i] = true;
      spans.add(
        CaptureSpan(kind: 'time', start: tokens[i].start, end: tokens[i].end),
      );
      continue;
    }
    // number followed by am/pm
    final num = int.tryParse(tokens[i].text);
    if (num != null && i + 1 < n && !used[i + 1]) {
      final ap = tokens[i + 1].text.toLowerCase();
      if (ap == 'am' || ap == 'pm') {
        var h = num;
        if (ap == 'pm' && h < 12) h += 12;
        if (ap == 'am' && h == 12) h = 0;
        if (startHour == null) {
          startHour = h;
          startMinute = 0;
        } else if (endHour == null) {
          endHour = h;
          endMinute = 0;
        }
        used[i] = true;
        used[i + 1] = true;
        spans.add(
          CaptureSpan(
            kind: 'time',
            start: tokens[i].start,
            end: tokens[i + 1].end,
          ),
        );
        i++;
        continue;
      }
    }
  }

  // Default kind adjustments.
  if (!prefixSet) {
    if (repeat != null) {
      kind = CaptureKind.habit;
    } else if (startHour != null && endHour != null) {
      kind = CaptureKind.event;
    } else if (countdown) {
      kind = CaptureKind.countdown;
    }
  }

  // Build date/time.
  DateTime? date;
  DateTime? startTime;
  DateTime? endTime;
  if (dateResolved != null) {
    date = DateTime(dateResolved.year, dateResolved.month, dateResolved.day);
  }
  if (startHour != null) {
    var base =
        dateResolved ??
        DateTime(resolvedNow.year, resolvedNow.month, resolvedNow.day);
    if (dateResolved == null) {
      final candidate = DateTime(
        base.year,
        base.month,
        base.day,
        startHour,
        startMinute ?? 0,
      );
      if (candidate.isBefore(resolvedNow)) {
        base = base.add(const Duration(days: 1));
      }
    }
    startTime = DateTime(
      base.year,
      base.month,
      base.day,
      startHour,
      startMinute ?? 0,
    );
    date ??= DateTime(base.year, base.month, base.day);
    if (endHour != null) {
      var endBase = base;
      var eh = endHour;
      var em = endMinute ?? 0;
      final endCandidate = DateTime(
        endBase.year,
        endBase.month,
        endBase.day,
        eh,
        em,
      );
      if (!endCandidate.isAfter(startTime)) {
        endBase = endBase.add(const Duration(days: 1));
      }
      endTime = DateTime(endBase.year, endBase.month, endBase.day, eh, em);
    }
  }

  // Title from unused tokens.
  final buf = StringBuffer();
  for (var i = 0; i < n; i++) {
    if (used[i]) continue;
    if (buf.isNotEmpty) buf.write(' ');
    buf.write(tokens[i].text);
  }
  var title = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();

  // Whitespace-collapse already; if empty keep? Spec never drop user text; if all consumed, title empty allowed.
  if (title.isEmpty && input.trim().isNotEmpty && spans.length == n) {
    // all consumed; title empty is fine
  }

  return CaptureDraft(
    kind: kind,
    title: title,
    date: date,
    startTime: startTime,
    endTime: endTime,
    repeat: repeat,
    listTag: listTag,
    priority: priority,
    spans: spans,
  );
}

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

// Need _parseTime to be nullable. Redefine as nullable returning.
DateTime _resolveDate(DateTime now, int day, int month) {
  var year = now.year;
  var d = DateTime(year, month, day);
  final today = DateTime(now.year, now.month, now.day);
  if (d.isBefore(today)) {
    d = DateTime(year + 1, month, day);
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

DateTime _nextWeekdayAfter(DateTime now, int wd, {required bool strict}) {
  var d = DateTime(now.year, now.month, now.day);
  do {
    d = d.add(const Duration(days: 1));
  } while (d.weekday != wd);
  return d;
}
