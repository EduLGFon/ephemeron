/// Pure helpers for the `/stream/:date/:zoom` route parameters.

library;

///
/// The date segment is `yyyy-MM-dd`; the only valid zoom level for this unit
/// is `day`. Invalid or missing values fall back to today's date and `day`.

const String streamDefaultZoom = 'day';

bool isValidStreamZoom(String? value) =>
    value != null && value.trim().toLowerCase() == streamDefaultZoom;

String normalizeStreamZoom(String? value) =>
    isValidStreamZoom(value) ? value!.trim().toLowerCase() : streamDefaultZoom;

String formatStreamDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime? tryParseStreamDate(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  try {
    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return DateTime(dt.year, dt.month, dt.day);
  } catch (_) {
    return null;
  }
}

DateTime _clockNow(DateTime? now, DateTime Function()? clock) =>
    clock?.call() ?? now ?? DateTime.now();

DateTime resolveStreamDate(
  String? raw, {
  DateTime? now,
  DateTime Function()? clock,
}) {
  final parsed = tryParseStreamDate(raw);
  if (parsed != null) return parsed;
  final current = _clockNow(now, clock);
  return DateTime(current.year, current.month, current.day);
}

class StreamRouteParams {
  const StreamRouteParams({required this.date, required this.zoom});

  final DateTime date;
  final String zoom;

  String get dateSegment => formatStreamDate(date);
  String get zoomSegment => normalizeStreamZoom(zoom);

  @override
  bool operator ==(Object other) =>
      other is StreamRouteParams && other.date == date && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(date, zoom);
}

StreamRouteParams parseStreamRouteParams({
  String? date,
  String? zoom,
  DateTime? now,
  DateTime Function()? clock,
}) {
  return StreamRouteParams(
    date: resolveStreamDate(date, now: now, clock: clock),
    zoom: normalizeStreamZoom(zoom),
  );
}

StreamRouteParams parseStreamRoutePath(
  String path, {
  DateTime? now,
  DateTime Function()? clock,
}) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  String? date;
  String? zoom;
  if (segments.length >= 2) {
    date = segments[segments.length - 2];
    zoom = segments.last;
  } else if (segments.length == 1) {
    date = segments.last;
  }
  return parseStreamRouteParams(date: date, zoom: zoom, now: now, clock: clock);
}

// Backwards/alternative naming aliases.
String streamDateSegment(DateTime date) => formatStreamDate(date);
DateTime? parseStreamDate(String? raw) => tryParseStreamDate(raw);
DateTime streamDateForSegment(
  String? raw, {
  DateTime? now,
  DateTime Function()? clock,
}) => resolveStreamDate(raw, now: now, clock: clock);
String streamZoomForSegment(String? raw) => normalizeStreamZoom(raw);
StreamRouteParams streamRouteParams({
  String? date,
  String? zoom,
  DateTime? now,
  DateTime Function()? clock,
}) => parseStreamRouteParams(date: date, zoom: zoom, now: now, clock: clock);
