// Pure spatial hit-test for Stream day marks.
//
// Given marks sorted by start time, their column layout, a viewport mapping
// pixel-y to epoch time, a focal pixel-y and the canvas width, returns the id
// of the mark under that point, or null. Timed marks are queried in
// O(log n + k) via a cached max-end prefix; no per-call full-list allocation.
// Units: focalY in logical pixels from canvas top; canvasWidth in logical
// pixels; times in epoch milliseconds.

import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/stream_mark_layout.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';

const int _minVisualMs = streamMarkMinVisualMinutes * 60 * 1000;

int _effectiveEndMs(StreamDayMark m) =>
    m.endMs < m.startMs + _minVisualMs ? m.startMs + _minVisualMs : m.endMs;

/// Candidate checks performed by the last [hitTestMark] call. Reset with
/// [resetHitTestCandidateChecks].
int hitTestCandidateChecks = 0;

void resetHitTestCandidateChecks() => hitTestCandidateChecks = 0;

final Expando<List<int>> _maxEndCache = Expando<List<int>>('maxEnd');

List<int> _maxEnds(List<StreamDayMark> marks) {
  final cached = _maxEndCache[marks];
  if (cached != null) return cached;
  final out = List<int>.filled(marks.length, 0);
  var running = 0;
  for (var i = 0; i < marks.length; i++) {
    final e = _effectiveEndMs(marks[i]);
    if (e > running) running = e;
    out[i] = running;
  }
  _maxEndCache[marks] = out;
  return out;
}

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
  hitTestCandidateChecks = 0;

  // Binary search: first index whose startMs > t.
  var lo = 0;
  var hi = marks.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (marks[mid].startMs <= t) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }

  final maxEnds = _maxEnds(marks);
  // First index whose running max-end >= t.
  var first = 0;
  var last = hi;
  while (first < last) {
    final mid = (first + last) >> 1;
    if (maxEnds[mid] < t) {
      first = mid + 1;
    } else {
      last = mid;
    }
  }

  int? result;
  for (var i = first; i < hi; i++) {
    hitTestCandidateChecks++;
    final m = marks[i];
    if (_effectiveEndMs(m) < t) continue;
    final l = layout[i];
    final rect = markColumnRect(
      column: l.column,
      columnCount: l.columnCount,
      canvasWidth: canvasWidth,
      top: 0,
      bottom: 0,
    );
    if (fx >= rect.left && fx <= rect.right) {
      result = i;
    }
  }
  if (result == null) return null;
  return marks[result].id;
}
