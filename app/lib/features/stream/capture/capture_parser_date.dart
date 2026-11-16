part of 'capture_parser.dart';

void _handleDateTime(_ParseState s) {
  final n = s.tokens.length;
  for (var i = 0; i < n; i++) {
    if (s.used[i]) continue;
    final dc = _tryDate(s, i, n);
    if (dc > 0) {
      i += dc - 1;
      continue;
    }
    final tc = _tryTime(s, i, n);
    if (tc > 0) {
      i += tc - 1;
      continue;
    }
  }
}
