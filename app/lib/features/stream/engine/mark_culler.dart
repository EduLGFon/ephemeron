class CulledRange {
  const CulledRange(this.start, this.end);
  final int start;
  final int end;
}

CulledRange cullMarks(
  List<int> starts,
  List<int> ends,
  int rangeStartMs,
  int rangeEndMs,
) {
  if (starts.isEmpty) return const CulledRange(0, 0);
  int hi = _upperBound(starts, rangeEndMs);
  int lo = hi;
  for (var i = 0; i < hi; i++) {
    if (ends[i] >= rangeStartMs) {
      lo = i;
      break;
    }
  }
  return CulledRange(lo, hi);
}

int _upperBound(List<int> values, int target) {
  int lo = 0;
  int hi = values.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (values[mid] <= target) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}
