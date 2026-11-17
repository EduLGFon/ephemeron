// Pure grouping model for the Stream Agenda lens.
//
// No Flutter import. Units: StreamDayMark.startMs is epoch milliseconds in
// LOCAL time (see stream_day_mark.dart / stream_mark_mapper.dart), so a local
// day is derived with DateTime.fromMillisecondsSinceEpoch(ms) (local).
import '../../application/stream_day_mark.dart';

/// One day's slice of the agenda, with its heading label and marks sorted by
/// start time.
class AgendaSection {
  const AgendaSection({
    required this.dayKey,
    required this.heading,
    required this.items,
  });

  /// Local midnight date for this day.
  final DateTime dayKey;

  /// Caller-supplied heading label (already localized).
  final String heading;

  /// Marks for this day, sorted by start time with stable tie-breaking.
  final List<StreamDayMark> items;
}

/// Groups [marks] into one [AgendaSection] per distinct local day.
///
/// Days are sorted ascending. Within a day, marks are sorted by [startMs]
/// ascending; ties keep their input order (stable). Days that contain no
/// marks are never produced. [headingFor] supplies the localized heading for
/// each day (required; no default English fallback).
List<AgendaSection> groupMarksByDay(
  List<StreamDayMark> marks, {
  required String Function(DateTime day) headingFor,
}) {
  final byDay = <DateTime, List<_IndexedMark>>{};
  for (var i = 0; i < marks.length; i++) {
    final mark = marks[i];
    final local = DateTime.fromMillisecondsSinceEpoch(mark.startMs);
    final day = DateTime(local.year, local.month, local.day);
    byDay.putIfAbsent(day, () => <_IndexedMark>[]).add(_IndexedMark(i, mark));
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days)
      AgendaSection(
        dayKey: day,
        heading: headingFor(day),
        items:
            (byDay[day]!..sort((a, b) {
                  final c = a.mark.startMs.compareTo(b.mark.startMs);
                  if (c != 0) return c;
                  return a.index.compareTo(b.index);
                }))
                .map((e) => e.mark)
                .toList(growable: false),
      ),
  ];
}

class _IndexedMark {
  const _IndexedMark(this.index, this.mark);
  final int index;
  final StreamDayMark mark;
}
