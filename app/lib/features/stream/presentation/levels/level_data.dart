// Pure Dart helpers for semantic-zoom levels: grouping StreamDayMark by
// local day and computing per-day counts and density for a date range.
//
// Time units: mark timestamps are epoch milliseconds in local time (see
// StreamDayMark). Date boundaries use local calendar days.
import 'package:ephemeron/features/stream/application/stream_day_mark.dart';

/// Per-day aggregate used by week/month levels.
class DayMarkCount {
  const DayMarkCount({
    required this.day,
    required this.count,
    required this.density,
  });

  /// Local midnight of the day.
  final DateTime day;

  /// Number of marks whose interval intersects this day.
  final int count;

  /// Normalized density in [0, 1], relative to the range maximum.
  final double density;
}

abstract final class LevelData {
  /// Local calendar date (midnight) for an epoch-ms timestamp.
  static DateTime localDay(int epochMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return DateTime(d.year, d.month, d.day);
  }

  /// Groups marks by their local start day.
  static Map<DateTime, List<StreamDayMark>> groupByLocalDay(
    Iterable<StreamDayMark> marks,
  ) {
    final result = <DateTime, List<StreamDayMark>>{};
    for (final m in marks) {
      final day = localDay(m.startMs);
      result.putIfAbsent(day, () => <StreamDayMark>[]).add(m);
    }
    return result;
  }

  /// Counts and densities for each day in [rangeStart, rangeEnd] (inclusive).
  ///
  /// [rangeStart]/[rangeEnd] are local dates; time components are ignored.
  /// Density is count / maxCount, clamped to [0, 1]; maxCount is the
  /// maximum count in the range (or [maxCountOverride] if provided).
  static List<DayMarkCount> countsForRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Iterable<StreamDayMark> marks,
    int? maxCountOverride,
  }) {
    final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
    final grouped = groupByLocalDay(marks);
    var maxCount = 0;
    final counts = <DateTime, int>{};
    var cursor = start;
    while (!cursor.isAfter(end)) {
      final c = grouped[cursor]?.length ?? 0;
      counts[cursor] = c;
      if (c > maxCount) maxCount = c;
      cursor = cursor.add(const Duration(days: 1));
    }
    final denom = maxCountOverride != null && maxCountOverride > 0
        ? maxCountOverride
        : (maxCount == 0 ? 1 : maxCount);
    final result = <DayMarkCount>[];
    cursor = start;
    while (!cursor.isAfter(end)) {
      final c = counts[cursor] ?? 0;
      result.add(
        DayMarkCount(
          day: cursor,
          count: c,
          density: (c / denom).clamp(0.0, 1.0),
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }
}
