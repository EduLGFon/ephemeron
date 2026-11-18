part of 'capture_parser.dart';

int _tryTime(_ParseState s, int i, int n) {
  final tokens = s.tokens;

  // time range single token
  if (tokens[i].text.contains('-')) {
    final parts = tokens[i].text.split('-');
    if (parts.length == 2) {
      final a = _parseTime(parts[0]);
      final b = _parseTime(parts[1]);
      if (a != null && b != null) {
        s.startHour = a.$1;
        s.startMinute = a.$2;
        s.endHour = b.$1;
        s.endMinute = b.$2;
        s.used[i] = true;
        s.spans.add(
          CaptureSpan(kind: 'time', start: tokens[i].start, end: tokens[i].end),
        );
        return 1;
      }
    }
  }

  // time token
  final tm = _parseTime(tokens[i].text);
  if (tm != null) {
    // range with following - time?
    if (i + 2 < n &&
        !s.used[i + 1] &&
        tokens[i + 1].text == '-' &&
        !s.used[i + 2]) {
      final tm2 = _parseTime(tokens[i + 2].text);
      if (tm2 != null) {
        s.startHour = tm.$1;
        s.startMinute = tm.$2;
        s.endHour = tm2.$1;
        s.endMinute = tm2.$2;
        s.used[i] = true;
        s.used[i + 1] = true;
        s.used[i + 2] = true;
        s.spans.add(
          CaptureSpan(
            kind: 'time',
            start: tokens[i].start,
            end: tokens[i + 2].end,
          ),
        );
        return 3;
      }
    }
    if (s.startHour == null) {
      s.startHour = tm.$1;
      s.startMinute = tm.$2;
    } else if (s.endHour == null) {
      s.endHour = tm.$1;
      s.endMinute = tm.$2;
    } else {
      // extra time stays in title
    }
    s.used[i] = true;
    s.spans.add(
      CaptureSpan(kind: 'time', start: tokens[i].start, end: tokens[i].end),
    );
    return 1;
  }

  // number followed by am/pm
  final num = int.tryParse(tokens[i].text);
  if (num != null && i + 1 < n && !s.used[i + 1]) {
    final ap = tokens[i + 1].text.toLowerCase();
    if (ap == 'am' || ap == 'pm') {
      var h = num;
      if (ap == 'pm' && h < 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      if (s.startHour == null) {
        s.startHour = h;
        s.startMinute = 0;
      } else if (s.endHour == null) {
        s.endHour = h;
        s.endMinute = 0;
      }
      s.used[i] = true;
      s.used[i + 1] = true;
      s.spans.add(
        CaptureSpan(
          kind: 'time',
          start: tokens[i].start,
          end: tokens[i + 1].end,
        ),
      );
      return 2;
    }
  }

  return 0;
}
