import 'dart:math' as math;
import 'dart:ui';

// Pure Dart overlap-column layout for stream marks.
//
// Packs marks whose time intervals overlap into side-by-side columns, like a
// calendar week view. Deterministic and O(n log n) (dominated by sorting).

/// Input interval for the layout helper.
class MarkInterval {
  const MarkInterval({required this.startMs, required this.endMs, this.id});

  final int startMs;
  final int endMs;
  final String? id;
}

/// Per-mark layout result.
class MarkLayout {
  const MarkLayout({required this.column, required this.columnCount});

  final int column;
  final int columnCount;

  @override
  bool operator ==(Object other) =>
      other is MarkLayout &&
      other.column == column &&
      other.columnCount == columnCount;

  @override
  int get hashCode => Object.hash(column, columnCount);
}

/// Minimum visual duration for very short marks, in minutes.
const int streamMarkMinVisualMinutes = 5;

/// Packs [marks] into columns. Returns a list parallel to [marks].
List<MarkLayout> layoutMarkColumns(
  List<MarkInterval> marks, {
  int minDurationMinutes = streamMarkMinVisualMinutes,
}) {
  if (marks.isEmpty) return const <MarkLayout>[];

  // Adjust min duration if caller overrides.
  final minMs = minDurationMinutes * 60 * 1000;
  int effEnd(MarkInterval m) {
    final end = m.endMs < m.startMs ? m.startMs : m.endMs;
    if (end - m.startMs < minMs) return m.startMs + minMs;
    return end;
  }

  // Sort indices by start, then id, then original index for determinism.
  final order = List<int>.generate(marks.length, (i) => i)
    ..sort((a, b) {
      final sa = marks[a].startMs;
      final sb = marks[b].startMs;
      if (sa != sb) return sa.compareTo(sb);
      final ia = marks[a].id ?? '';
      final ib = marks[b].id ?? '';
      if (ia != ib) return ia.compareTo(ib);
      return a.compareTo(b);
    });

  final column = List<int>.filled(marks.length, 0);
  final columnCountPer = List<int>.filled(marks.length, 1);

  // Connected overlap clusters.
  var i = 0;
  while (i < order.length) {
    // Build cluster.
    final cluster = <int>[order[i]];
    var clusterEnd = effEnd(marks[order[i]]);
    var j = i + 1;
    while (j < order.length && marks[order[j]].startMs < clusterEnd) {
      cluster.add(order[j]);
      final e = effEnd(marks[order[j]]);
      if (e > clusterEnd) clusterEnd = e;
      j++;
    }
    // Greedy column assignment within cluster, sorted by start.
    final sortedCluster = List<int>.from(cluster)
      ..sort((a, b) {
        if (marks[a].startMs != marks[b].startMs) {
          return marks[a].startMs.compareTo(marks[b].startMs);
        }
        final ia = marks[a].id ?? '';
        final ib = marks[b].id ?? '';
        if (ia != ib) return ia.compareTo(ib);
        return a.compareTo(b);
      });
    final colEnds = <int>[];
    for (final idx in sortedCluster) {
      final s = marks[idx].startMs;
      final e = effEnd(marks[idx]);
      var assigned = -1;
      for (var c = 0; c < colEnds.length; c++) {
        if (colEnds[c] <= s) {
          assigned = c;
          colEnds[c] = e;
          break;
        }
      }
      if (assigned == -1) {
        assigned = colEnds.length;
        colEnds.add(e);
      }
      column[idx] = assigned;
    }
    final cols = colEnds.isEmpty ? 1 : colEnds.length;
    for (final idx in cluster) {
      columnCountPer[idx] = cols;
    }
    i = j;
  }

  return List<MarkLayout>.generate(
    marks.length,
    (k) => MarkLayout(column: column[k], columnCount: columnCountPer[k]),
  );
}

/// Shared column geometry for a mark, matching [DayCanvasPainter].
///
/// [top]/[bottom] are pixel y bounds; only left/right are derived from the
/// column layout so painter and hit-test agree exactly.
Rect markColumnRect({
  required int column,
  required int columnCount,
  required double canvasWidth,
  required double top,
  required double bottom,
}) {
  final cols = columnCount < 1 ? 1 : columnCount;
  final available = (canvasWidth - 8).clamp(1.0, double.infinity);
  final colWidth = available / cols;
  final left = 4.0 + column * colWidth;
  final right = math.max(left, left + colWidth - 4);
  return Rect.fromLTRB(left, top, right, bottom);
}
