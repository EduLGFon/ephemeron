// Pure, O(log n + k) spatial hit-test for Stream day marks.
//
// Given marks sorted by start time, their column layout, a viewport mapping
// pixel-y to epoch time, a focal pixel-y and the canvas width, returns the id
// of the mark under that point, or null. Binary search narrows by time; a
// column check resolves overlaps. Units: focalY in logical pixels measured
// from the top of the canvas; canvasWidth in logical pixels; times in epoch
// milliseconds.

import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/stream_mark_layout.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';

const int _minVisualMs = streamMarkMinVisualMinutes * 60 * 1000;

int _effectiveEndMs(StreamDayMark m) =>
    m.endMs < m.startMs + _minVisualMs ? m.startMs + _minVisualMs : m.endMs;

/// Returns the id of the mark under (focalY, focalX) or null.
String? hitTestMark({
  required List<StreamDayMark> marks,
  required List<MarkLayout> layout,
  required StreamTimeViewport viewport,
  required double focalY,
  required double canvasWidth,
  double? focalX,
  double edgeMarginDp = 24,
}) {
  if (marks.isEmpty || layout.length != marks.length) return null;
  final height = viewport.viewportHeight;
  if (focalY < 0 || (height > 0 && focalY > height)) return null;
  final fx = focalX ?? canvasWidth / 2;
  if (fx < edgeMarginDp || fx > canvasWidth - edgeMarginDp) return null;

  final t = viewport.pxToTime(focalY);

  // Binary search: first index whose startMs > t.
  final starts = marks.map((m) => m.startMs).toList(growable: false);
  var lo = 0;
  var hi = starts.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (starts[mid] <= t) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }

  // Among marks with startMs <= t, keep those whose effective end >= t and
  // whose column rect contains fx. Later marks draw on top, so keep the last.
  int? result;
  for (var i = 0; i < lo; i++) {
    final m = marks[i];
    if (_effectiveEndMs(m) < t) continue;
    final l = layout[i];
    final cols = l.columnCount < 1 ? 1 : l.columnCount;
    final available = (canvasWidth - 8).clamp(1.0, double.infinity);
    final colWidth = available / cols;
    final left = 4.0 + l.column * colWidth;
    final right = left + colWidth;
    if (fx >= left && fx <= right) {
      result = i;
    }
  }
  if (result == null) return null;
  return marks[result].id;
}

/// Stateful convenience wrapper around [hitTestMark].
class MarkHitTest {
  MarkHitTest({
    required this.marks,
    required this.layout,
    required this.viewport,
    required this.canvasWidth,
    this.edgeMarginDp = 24,
  });

  final List<StreamDayMark> marks;
  final List<MarkLayout> layout;
  final StreamTimeViewport viewport;
  final double canvasWidth;
  final double edgeMarginDp;

  String? at({required double focalY, double? focalX}) => hitTestMark(
    marks: marks,
    layout: layout,
    viewport: viewport,
    focalY: focalY,
    canvasWidth: canvasWidth,
    focalX: focalX,
    edgeMarginDp: edgeMarginDp,
  );
}

typedef MarkHitTester = MarkHitTest;
