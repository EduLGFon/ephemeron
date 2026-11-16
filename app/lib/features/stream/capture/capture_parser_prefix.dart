part of 'capture_parser.dart';

void _handlePrefix(_ParseState s) {
  final n = s.tokens.length;
  if (n <= 1) return;
  final first = s.tokens[0].text.toLowerCase();
  CaptureKind? pk;
  if (first == 't') pk = CaptureKind.task;
  if (first == 'e') pk = CaptureKind.event;
  if (first == 'h') pk = CaptureKind.habit;
  if (first == 'c') pk = CaptureKind.countdown;
  if (pk == null) return;
  s.kind = pk;
  s.prefixSet = true;
  s.used[0] = true;
  s.spans.add(
    CaptureSpan(kind: 'type', start: s.tokens[0].start, end: s.tokens[0].end),
  );
}
