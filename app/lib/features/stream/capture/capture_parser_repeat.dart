part of 'capture_parser.dart';

void _handleRepeat(_ParseState s) {
  final n = s.tokens.length;
  for (var i = 0; i < n; i++) {
    if (s.used[i]) continue;
    if (s.repeat != null) continue; // later rules stay in title
    final w = s.tokens[i].text.toLowerCase();
    if (dailyWords[s.locale]!.contains(w)) {
      s.repeat = const CaptureRepeat(frequency: CaptureRepeatFrequency.daily);
      s.used[i] = true;
      s.spans.add(
        CaptureSpan(
          kind: 'repeat',
          start: s.tokens[i].start,
          end: s.tokens[i].end,
        ),
      );
      continue;
    }
    if (!repeatStartWords[s.locale]!.contains(w)) continue;
    // daily phrase?
    if (i + 1 < n &&
        !s.used[i + 1] &&
        dayWords[s.locale]!.contains(s.tokens[i + 1].text.toLowerCase())) {
      s.repeat = const CaptureRepeat(frequency: CaptureRepeatFrequency.daily);
      s.used[i] = true;
      s.used[i + 1] = true;
      s.spans.add(
        CaptureSpan(
          kind: 'repeat',
          start: s.tokens[i].start,
          end: s.tokens[i + 1].end,
        ),
      );
      continue;
    }
    // collect weekdays
    var j = i + 1;
    final wds = <int>[];
    while (j < n && !s.used[j]) {
      final wd = weekdays[s.locale]![s.tokens[j].text.toLowerCase()];
      if (wd == null) break;
      wds.add(wd);
      j++;
    }
    if (wds.isNotEmpty) {
      s.repeat = CaptureRepeat(
        frequency: CaptureRepeatFrequency.weekly,
        weekdays: wds,
      );
      for (var k = i; k < j; k++) {
        s.used[k] = true;
      }
      s.spans.add(
        CaptureSpan(
          kind: 'repeat',
          start: s.tokens[i].start,
          end: s.tokens[j - 1].end,
        ),
      );
      i = j - 1;
    }
  }
}
