/// Pure fuzzy matcher. Deterministic, case-insensitive, locale-agnostic.
library;

int fuzzyScore(String query, String candidate) {
  final q = query.trim().toLowerCase();
  final c = candidate.toLowerCase();
  if (q.isEmpty) return 0;
  if (c.isEmpty) return -1;

  var qi = 0;
  var score = 0;
  var consecutive = 0;
  var lastMatch = -2;
  for (var ci = 0; ci < c.length && qi < q.length; ci++) {
    if (c[ci] != q[qi]) {
      consecutive = 0;
      continue;
    }
    // Word-start bonus.
    final wordStart =
        ci == 0 || c[ci - 1] == ' ' || c[ci - 1] == '-' || c[ci - 1] == '_';
    if (wordStart) score += 10;
    // Consecutive bonus.
    if (ci == lastMatch + 1) {
      consecutive++;
      score += 5 * consecutive;
    } else {
      consecutive = 0;
    }
    lastMatch = ci;
    qi++;
    score += 1;
  }
  if (qi < q.length) return -1;
  // Prefix bonus.
  if (c.startsWith(q)) score += 20;
  return score;
}

List<T> fuzzyRank<T>(String query, List<T> items, String Function(T) label) {
  final scored = <({int index, int score, T item})>[];
  for (var i = 0; i < items.length; i++) {
    final s = fuzzyScore(query, label(items[i]));
    if (s < 0) continue;
    scored.add((index: i, score: s, item: items[i]));
  }
  scored.sort((a, b) {
    final cmp = b.score.compareTo(a.score);
    if (cmp != 0) return cmp;
    return a.index.compareTo(b.index);
  });
  return scored.map((e) => e.item).toList(growable: false);
}
