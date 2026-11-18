part of 'capture_parser.dart';

void _handleCountdown(_ParseState s) {
  final n = s.tokens.length;
  for (var i = 0; i < n; i++) {
    if (s.used[i]) continue;
    final w = s.tokens[i].text.toLowerCase();
    if (countdownWords[s.locale]!.contains(w)) {
      if (!s.prefixSet) {
        s.kind = CaptureKind.countdown;
        s.countdown = true;
      }
      s.used[i] = true;
      s.spans.add(
        CaptureSpan(
          kind: 'type',
          start: s.tokens[i].start,
          end: s.tokens[i].end,
        ),
      );
    }
  }
}
