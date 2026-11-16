// Pure mapping from calendar occurrence rows to Stream day marks.
//
// Units: occurrence timestamps are stored as UTC epoch milliseconds
// (startUtc/endUtc). StreamDayMark.startMs/endMs are epoch milliseconds in
// LOCAL time. All-day rows use their dayKey (a local date string) rather
// than startUtc.toLocal(), because the row is stored at UTC midnight.
import 'stream_day_mark.dart';

class OccurrenceRow {
  const OccurrenceRow({
    required this.id,
    required this.eventId,
    required this.sourceType,
    required this.startUtc,
    required this.endUtc,
    required this.dayKey,
    this.title,
    this.colorId,
  });

  final String id;
  final String eventId;
  final String sourceType;
  final int startUtc;
  final int endUtc;
  final String dayKey;
  final String? title;
  final String? colorId;
}

class StreamDayMarkMappingResult {
  const StreamDayMarkMappingResult({
    required this.marks,
    required this.skipped,
  });

  final List<StreamDayMark> marks;
  final int skipped;
}

const int _minVisibleDurationMs = 15 * 60 * 1000;

StreamDayMarkMappingResult mapOccurrencesToMarks(List<OccurrenceRow> rows) {
  final marks = <StreamDayMark>[];
  var skipped = 0;
  for (final row in rows) {
    if (!_valid(row)) {
      skipped++;
      continue;
    }
    final mark = _mapRow(row);
    if (mark == null) {
      skipped++;
      continue;
    }
    marks.add(mark);
  }
  marks.sort((a, b) => a.startMs.compareTo(b.startMs));
  return StreamDayMarkMappingResult(marks: marks, skipped: skipped);
}

bool _valid(OccurrenceRow row) {
  if (row.id.isEmpty || row.eventId.isEmpty || row.dayKey.isEmpty) return false;
  if (row.sourceType != 'event' && row.sourceType != 'task') return false;
  if (row.startUtc < 0) return false;
  return true;
}

StreamDayMark? _mapRow(OccurrenceRow row) {
  final kind = row.sourceType == 'task'
      ? StreamDayMarkKind.task
      : StreamDayMarkKind.event;
  final allDay =
      (row.endUtc - row.startUtc) >= const Duration(hours: 23).inMilliseconds;
  if (allDay) {
    final parts = row.dayKey.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    final spanMs = row.endUtc - row.startUtc;
    final days = spanMs <= 0
        ? 1
        : (spanMs / Duration(days: 1).inMilliseconds).ceil();
    final start = DateTime(y, m, d);
    final end = DateTime(y, m, d + days);
    return StreamDayMark(
      id: row.id,
      kind: kind,
      startMs: start.millisecondsSinceEpoch,
      endMs: end.millisecondsSinceEpoch,
      title: row.title ?? '',
      colorArgb: _colorArgb(row.colorId),
      sourceTaskOrEventId: row.eventId,
      isAllDay: true,
    );
  }
  final startLocal = DateTime.fromMillisecondsSinceEpoch(
    row.startUtc,
    isUtc: true,
  ).toLocal();
  final endLocal = DateTime.fromMillisecondsSinceEpoch(
    row.endUtc,
    isUtc: true,
  ).toLocal();
  var startMs = startLocal.millisecondsSinceEpoch;
  var endMs = endLocal.millisecondsSinceEpoch;
  if (endMs <= startMs || endMs - startMs < _minVisibleDurationMs) {
    endMs = startMs + _minVisibleDurationMs;
  }
  return StreamDayMark(
    id: row.id,
    kind: kind,
    startMs: startMs,
    endMs: endMs,
    title: row.title ?? '',
    colorArgb: _colorArgb(row.colorId),
    sourceTaskOrEventId: row.eventId,
    isAllDay: false,
  );
}

const Map<String, int> _paletteArgb = <String, int>{
  '1': 0xFF7986CB,
  '2': 0xFF33B679,
  '3': 0xFF8E24AA,
  '4': 0xFFE67C73,
  '5': 0xFFF6BF26,
  '6': 0xFF3F51B5,
  '7': 0xFF039BE5,
  '8': 0xFF0B8043,
  '9': 0xFFD50000,
  '10': 0xFF303F9F,
  '11': 0xFF616161,
};

int _colorArgb(String? colorId) {
  if (colorId == null || colorId.isEmpty) return 0xFF1976D2;
  final palette = _paletteArgb[colorId];
  if (palette != null) return palette;
  var hex = colorId.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6 || hex.length == 8) {
    var ok = true;
    for (var i = 0; i < hex.length; i++) {
      final c = hex.codeUnitAt(i);
      final isHex =
          (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102);
      if (!isHex) {
        ok = false;
        break;
      }
    }
    if (ok) {
      final v = int.parse(hex, radix: 16);
      return hex.length == 6 ? (0xFF000000 | v) : v;
    }
  }
  return 0xFF1976D2;
}
