// Pure mapping from calendar occurrence rows to Stream marks.
//
// Units: occurrence timestamps are stored as UTC epoch milliseconds
// (startUtc/endUtc). StreamMark.startMs/endMs are epoch milliseconds in
// LOCAL time, so a mark can be positioned on a local-day axis without
// extra conversion at render time.
import 'stream_mark.dart';

/// Minimal occurrence-row shape used by [mapOccurrencesToMarks]. Keeps the
/// mapper free of Drift so it can be unit-tested with plain values.
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

/// Result of [mapOccurrencesToMarks]: the sorted marks plus how many input
/// rows were skipped because they were malformed or of an unsupported kind.
class StreamMarkMappingResult {
  const StreamMarkMappingResult({required this.marks, required this.skipped});

  final List<StreamMark> marks;
  final int skipped;
}

const int _minVisibleDurationMs = 15 * 60 * 1000; // 15 minutes
const int _allDayThresholdMs = 23 * 60 * 60 * 1000; // >= 23 hours

StreamMarkMappingResult mapOccurrencesToMarks(List<OccurrenceRow> rows) {
  final marks = <StreamMark>[];
  var skipped = 0;
  for (final row in rows) {
    if (row.id.isEmpty ||
        row.eventId.isEmpty ||
        row.dayKey.isEmpty ||
        (row.sourceType != 'event' && row.sourceType != 'task')) {
      skipped++;
      continue;
    }
    if (row.startUtc < 0 || row.endUtc < row.startUtc) {
      // Negative durations are repaired below; a missing/invalid start is
      // the only hard failure here.
      if (row.startUtc < 0) {
        skipped++;
        continue;
      }
    }

    final kind = row.sourceType == 'task'
        ? StreamMarkKind.task
        : StreamMarkKind.event;

    final allDay = (row.endUtc - row.startUtc) >= _allDayThresholdMs;

    // Convert UTC epoch ms to local epoch ms.
    final startLocal = DateTime.fromMillisecondsSinceEpoch(
      row.startUtc,
      isUtc: true,
    ).toLocal();
    final endLocal = DateTime.fromMillisecondsSinceEpoch(
      row.endUtc,
      isUtc: true,
    ).toLocal();

    int startMs;
    int endMs;
    if (allDay) {
      final midnight = DateTime(
        startLocal.year,
        startLocal.month,
        startLocal.day,
      );
      startMs = midnight.millisecondsSinceEpoch;
      endMs = midnight.add(const Duration(days: 1)).millisecondsSinceEpoch;
    } else {
      startMs = startLocal.millisecondsSinceEpoch;
      endMs = endLocal.millisecondsSinceEpoch;
      if (endMs <= startMs) {
        endMs = startMs + _minVisibleDurationMs;
      } else if (endMs - startMs < _minVisibleDurationMs) {
        endMs = startMs + _minVisibleDurationMs;
      }
    }

    final colorArgb = _colorArgb(row.colorId);

    marks.add(
      StreamMark(
        id: row.id,
        kind: kind,
        startMs: startMs,
        endMs: endMs,
        title: row.title ?? '',
        colorArgb: colorArgb,
        sourceTaskOrEventId: row.eventId,
        isAllDay: allDay,
      ),
    );
  }
  marks.sort((a, b) => a.startMs.compareTo(b.startMs));
  return StreamMarkMappingResult(marks: marks, skipped: skipped);
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
  // CSS hex '#rrggbb' / '#aarrggbb'.
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
