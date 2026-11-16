// Riverpod providers exposing Stream marks derived from the calendar occurrence
// cache. Presentation/application layer only: no widgets, no Drift writes.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drift/app_database.dart' show OccurrenceCacheData;
import '../../../features/calendar/application/calendar_providers.dart'
    show calendarBuiltRangeProvider, windowOccurrencesProvider;
import '../../../features/calendar/application/calendar_state.dart'
    show CalendarRange;
import 'stream_mark.dart';
import 'stream_mark_mapper.dart';

/// Key for a single local day in the Stream view.
class StreamDayKey {
  const StreamDayKey({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  DateTime get date => DateTime(year, month, day);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamDayKey &&
          other.year == year &&
          other.month == month &&
          other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Calendar range covering the day plus its immediate neighbours, so marks
/// that cross midnight are not lost.
CalendarRange streamDayRange(StreamDayKey key) {
  final from = DateTime.utc(key.year, key.month, key.day - 1);
  final to = DateTime.utc(key.year, key.month, key.day + 2);
  return CalendarRange(fromUtc: from, toUtc: to);
}

OccurrenceRow occurrenceToRow(OccurrenceCacheData o) => OccurrenceRow(
  id: o.id,
  eventId: o.eventId,
  sourceType: o.sourceType,
  startUtc: o.startUtc,
  endUtc: o.endUtc,
  dayKey: o.dayKey,
  title: o.title,
  colorId: o.colorId,
);

/// Marks for a single Stream day, derived from the occurrence cache.
final streamMarksForDayProvider =
    FutureProvider.family<List<StreamMark>, StreamDayKey>((ref, key) async {
      final range = streamDayRange(key);
      final built = ref.watch(calendarBuiltRangeProvider);
      if (built == null || !built.covers(range)) {
        return const <StreamMark>[];
      }
      final rows = await ref.watch(windowOccurrencesProvider(range).future);
      final mapped = mapOccurrencesToMarks(
        rows.map(occurrenceToRow).toList(growable: false),
      );
      final dayStart = DateTime(
        key.year,
        key.month,
        key.day,
      ).millisecondsSinceEpoch;
      final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;
      return mapped.marks
          .where((m) => m.startMs < dayEnd && m.endMs > dayStart)
          .toList(growable: false);
    });
