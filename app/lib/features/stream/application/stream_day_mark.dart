// Presentation value type for one mark on the Stream timeline.
//
// Pure Dart: no Flutter, no Drift. Units are epoch milliseconds in local
// time (see stream_mark_mapper.dart for the conversion contract).
enum StreamDayMarkKind { event, task }

class StreamDayMark {
  const StreamDayMark({
    required this.id,
    required this.kind,
    required this.startMs,
    required this.endMs,
    required this.title,
    required this.colorArgb,
    this.sourceTaskOrEventId,
    this.isAllDay = false,
  });

  final String id;
  final StreamDayMarkKind kind;
  final int startMs;
  final int endMs;
  final String title;
  final int colorArgb;
  final String? sourceTaskOrEventId;
  final bool isAllDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamDayMark &&
          other.id == id &&
          other.kind == kind &&
          other.startMs == startMs &&
          other.endMs == endMs &&
          other.title == title &&
          other.colorArgb == colorArgb &&
          other.sourceTaskOrEventId == sourceTaskOrEventId &&
          other.isAllDay == isAllDay;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    startMs,
    endMs,
    title,
    colorArgb,
    sourceTaskOrEventId,
    isAllDay,
  );
}
