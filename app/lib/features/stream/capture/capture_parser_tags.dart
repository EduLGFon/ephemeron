part of 'capture_parser.dart';

void _handleTagsAndPriorities(_ParseState s) {
  final n = s.tokens.length;
  for (var i = 0; i < n; i++) {
    if (s.used[i]) continue;
    final t = s.tokens[i].text;
    if (t.startsWith('#') && t.length > 1) {
      if (s.listTag == null) {
        s.listTag = t.substring(1);
        s.used[i] = true;
        s.spans.add(
          CaptureSpan(
            kind: 'tag',
            start: s.tokens[i].start,
            end: s.tokens[i].end,
          ),
        );
      }
      // Later #tags stay in the title.
    } else if (t.startsWith('!') && t.length > 1) {
      final w = t.substring(1).toLowerCase();
      final p = priorityWords[w];
      if (p != null) {
        s.priority = p;
        s.used[i] = true;
        s.spans.add(
          CaptureSpan(
            kind: 'priority',
            start: s.tokens[i].start,
            end: s.tokens[i].end,
          ),
        );
      }
      // Unknown priority stays in the title.
    }
  }
}
