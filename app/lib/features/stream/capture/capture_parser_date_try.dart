part of 'capture_parser.dart';

int _tryDate(_ParseState s, int i, int n) {
  final w = s.tokens[i].text.toLowerCase();

  // today
  if (todayWords[s.locale]!.contains(w)) {
    if (s.dateResolved != null) return 0;
    s.dateResolved = DateTime(s.now.year, s.now.month, s.now.day);
    s.used[i] = true;
    s.spans.add(
      CaptureSpan(kind: 'date', start: s.tokens[i].start, end: s.tokens[i].end),
    );
    return 1;
  }
  // tomorrow
  if (tomorrowWords[s.locale]!.contains(w)) {
    final d = DateTime(
      s.now.year,
      s.now.month,
      s.now.day,
    ).add(const Duration(days: 1));
    s.dateResolved = d;
    s.used[i] = true;
    s.spans.add(
      CaptureSpan(kind: 'date', start: s.tokens[i].start, end: s.tokens[i].end),
    );
    return 1;
  }
  // next weekday
  if (nextWords[s.locale]!.contains(w) && i + 1 < n && !s.used[i + 1]) {
    final wd = weekdays[s.locale]![s.tokens[i + 1].text.toLowerCase()];
    if (wd != null) {
      if (s.dateResolved != null) return 0;
      s.dateResolved = _nextWeekdayAfter(s.now, wd);
      s.used[i] = true;
      s.used[i + 1] = true;
      s.spans.add(
        CaptureSpan(
          kind: 'date',
          start: s.tokens[i].start,
          end: s.tokens[i + 1].end,
        ),
      );
      return 2;
    }
  }
  // in X days/hours
  if (inWords[s.locale]!.contains(w) &&
      i + 2 < n &&
      !s.used[i + 1] &&
      !s.used[i + 2]) {
    final num = int.tryParse(s.tokens[i + 1].text);
    final dw = s.tokens[i + 2].text.toLowerCase();
    if (num != null && dayWords[s.locale]!.contains(dw)) {
      s.dateResolved = DateTime(
        s.now.year,
        s.now.month,
        s.now.day,
      ).add(Duration(days: num));
      s.used[i] = true;
      s.used[i + 1] = true;
      s.used[i + 2] = true;
      s.spans.add(
        CaptureSpan(
          kind: 'date',
          start: s.tokens[i].start,
          end: s.tokens[i + 2].end,
        ),
      );
      return 3;
    }
    if (num != null && hourWords[s.locale]!.contains(dw)) {
      if (s.dateResolved != null) return 0;
      final dt = s.now.add(Duration(hours: num));
      s.dateResolved = DateTime(dt.year, dt.month, dt.day);
      s.startHour = dt.hour;
      s.startMinute = dt.minute;
      s.used[i] = true;
      s.used[i + 1] = true;
      s.used[i + 2] = true;
      s.spans.add(
        CaptureSpan(
          kind: 'time',
          start: s.tokens[i].start,
          end: s.tokens[i + 2].end,
        ),
      );
      return 3;
    }
  }
  // day month
  final dayNum = int.tryParse(s.tokens[i].text);
  if (dayNum != null && i + 1 < n && !s.used[i + 1]) {
    final m = months[s.locale]![s.tokens[i + 1].text.toLowerCase()];
    if (m != null) {
      if (s.dateResolved != null) return 0;
      final resolved = _resolveDate(s.now, dayNum, m);
      if (resolved != null) {
        s.dateResolved = resolved;
        s.used[i] = true;
        s.used[i + 1] = true;
        s.spans.add(
          CaptureSpan(
            kind: 'date',
            start: s.tokens[i].start,
            end: s.tokens[i + 1].end,
          ),
        );
        return 2;
      }
    }
  }
  // month day
  if (months[s.locale]!.containsKey(w) && i + 1 < n && !s.used[i + 1]) {
    final dayNum2 = int.tryParse(s.tokens[i + 1].text);
    if (dayNum2 != null) {
      if (s.dateResolved != null) return 0;
      final m = months[s.locale]![w]!;
      final resolved = _resolveDate(s.now, dayNum2, m);
      if (resolved != null) {
        s.dateResolved = resolved;
        s.used[i] = true;
        s.used[i + 1] = true;
        s.spans.add(
          CaptureSpan(
            kind: 'date',
            start: s.tokens[i].start,
            end: s.tokens[i + 1].end,
          ),
        );
        return 2;
      }
    }
  }
  // standalone weekday as date
  final wd = weekdays[s.locale]![w];
  if (wd != null) {
    // Keep weekdays that belong to an unconsumed repeat rule in the title.
    if (i > 0 &&
        !s.used[i - 1] &&
        repeatStartWords[s.locale]!.contains(
          s.tokens[i - 1].text.toLowerCase(),
        )) {
      return 0;
    }
    s.dateResolved = _nextWeekdayOnOrAfter(s.now, wd);
    s.used[i] = true;
    s.spans.add(
      CaptureSpan(kind: 'date', start: s.tokens[i].start, end: s.tokens[i].end),
    );
    return 1;
  }

  return 0;
}
