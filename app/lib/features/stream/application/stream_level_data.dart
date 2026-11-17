// Range access for the Week and Month semantic-zoom levels.
//
// Units: StreamDayMark.startMs/endMs are epoch milliseconds in LOCAL time
// (see stream_mark_mapper.dart). StreamLevelRange.start/end are local
// calendar dates, start inclusive and end exclusive. The occurrence query
// uses the half-open UTC window derived from those local midnights, so a
// local week/month never drops rows that only overlap at the edges.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/application/calendar_providers.dart'
    show calendarBuiltRangeProvider, windowOccurrencesProvider;
import '../../calendar/application/calendar_state.dart' show CalendarRange;
import 'stream_day_mark.dart';
import 'stream_day_providers.dart' show occurrenceToRow;
import 'stream_mark_mapper.dart';

enum StreamLevel { day, week, month }

/// Local calendar range for one zoom level. [start] is inclusive, [end]
/// exclusive; both are normalized to local midnight.
class StreamLevelRange {
  StreamLevelRange({
    required this.level,
    required DateTime start,
    required DateTime end,
  }) : start = _localDate(start),
       end = _localDate(end);

  final StreamLevel level;
  final DateTime start;
  final DateTime end;

  static DateTime _localDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamLevelRange &&
          other.level == level &&
          other.start == start &&
          other.end == end;

  @override
  int get hashCode => Object.hash(level, start, end);
}

/// Local start of the week containing [date].
///
/// Calendar arithmetic uses the DateTime constructor (`day - offset`) rather
/// than Duration(days:), which would drift across a DST transition.
DateTime streamWeekStart(
  DateTime date, {
  int firstDayOfWeek = DateTime.monday,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final offset = (day.weekday - firstDayOfWeek + 7) % 7;
  return DateTime(day.year, day.month, day.day - offset);
}

StreamLevelRange streamMonthRange(DateTime date) {
  final first = DateTime(date.year, date.month, 1);
  return StreamLevelRange(
    level: StreamLevel.month,
    start: first,
    end: DateTime(date.year, date.month + 1, 1),
  );
}

/// Local range for [level] around [date].
///
/// [firstDayOfWeek] affects the week range only; day and month ranges are
/// independent of it.
StreamLevelRange streamLevelRangeFor(
  StreamLevel level,
  DateTime date, {
  int firstDayOfWeek = DateTime.monday,
}) {
  switch (level) {
    case StreamLevel.day:
      final start = DateTime(date.year, date.month, date.day);
      return StreamLevelRange(
        level: level,
        start: start,
        end: DateTime(start.year, start.month, start.day + 1),
      );
    case StreamLevel.week:
      final start = streamWeekStart(date, firstDayOfWeek: firstDayOfWeek);
      return StreamLevelRange(
        level: level,
        start: start,
        end: DateTime(start.year, start.month, start.day + 7),
      );
    case StreamLevel.month:
      return streamMonthRange(date);
  }
}

/// Half-open UTC query window for a local level range.
CalendarRange streamLevelQueryRange(StreamLevelRange range) =>
    CalendarRange(fromUtc: range.start.toUtc(), toUtc: range.end.toUtc());

class StreamLevelMarks {
  const StreamLevelMarks({
    required this.marks,
    required this.skipped,
    required this.covered,
  });

  final List<StreamDayMark> marks;
  final int skipped;

  /// False when the cache does not yet materialize the whole range; the
  /// surface then requests a rebuild via StreamDayCacheController.ensure.
  final bool covered;
}

final streamLevelMarksProvider =
    FutureProvider.family<StreamLevelMarks, StreamLevelRange>((
      ref,
      range,
    ) async {
      final query = streamLevelQueryRange(range);
      final built = ref.watch(calendarBuiltRangeProvider);
      if (built == null || !built.covers(query)) {
        return const StreamLevelMarks(
          marks: <StreamDayMark>[],
          skipped: 0,
          covered: false,
        );
      }
      final rows = await ref.watch(windowOccurrencesProvider(query).future);
      final mapped = mapOccurrencesToMarks(
        rows.map(occurrenceToRow).toList(growable: false),
      );
      final startMs = range.start.millisecondsSinceEpoch;
      final endMs = range.end.millisecondsSinceEpoch;
      final marks = mapped.marks
          .where((m) => m.startMs < endMs && m.endMs > startMs)
          .toList(growable: false);
      return StreamLevelMarks(
        marks: marks,
        skipped: mapped.skipped,
        covered: true,
      );
    });
