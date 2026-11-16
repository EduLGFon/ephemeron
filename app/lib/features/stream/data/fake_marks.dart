import 'dart:math';

class StreamMark {
  const StreamMark({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.title,
    required this.color,
  });

  final int id;
  final int startMs;
  final int endMs;
  final String title;
  final int color;
}

/// Deterministic seeded generator: 2000 synthetic marks spread over ~1 year.
/// Titles are synthetic; no personal data.
List<StreamMark> generateFakeMarks({int count = 2000, int seed = 42}) {
  final rng = Random(seed);
  const base = 1735689600000; // 2025-01-01 UTC approx
  final marks = <StreamMark>[];
  for (var i = 0; i < count; i++) {
    final start = base + rng.nextInt(365) * 86400000 + rng.nextInt(86400000);
    final durMin = 15 + rng.nextInt(105);
    final end = start + durMin * 60 * 1000;
    final color = 0xFF000000 | (rng.nextInt(0xFFFFFF));
    marks.add(
      StreamMark(
        id: i,
        startMs: start,
        endMs: end,
        title: 'Mark ${i.toString().padLeft(4, '0')}',
        color: color,
      ),
    );
  }
  marks.sort((a, b) => a.startMs.compareTo(b.startMs));
  return marks;
}
