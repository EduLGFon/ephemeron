// Pure calendar-date helpers for slipped-task triage.
//
// Task dates are local YYYY-MM-DD strings. Overdue day counts compare UTC
// midnights built from those local components, so DST transitions never add
// or remove a day. Planned start/end values are local ISO minutes.
import '../../../core/time/time.dart';

/// Parses a local `YYYY-MM-DD` key. Invalid or impossible dates return null.
DateTime? parseSlippedDateKey(String? value) {
  if (value == null || value.length != 10) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// Parses a stored local `YYYY-MM-DDTHH:mm` value.
DateTime? parseSlippedLocalIso(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

DateTime localDayOf(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime utcDayOf(DateTime localDay) =>
    DateTime.utc(localDay.year, localDay.month, localDay.day);

/// Whole days from [dueDate]/[plannedDate] to [today], or null when neither
/// date is before today. The earliest valid date wins: that is when the task
/// first slipped.
int? slippedDaysOverdue({
  required DateTime today,
  String? dueDate,
  String? plannedDate,
}) {
  final due = parseSlippedDateKey(dueDate);
  final planned = parseSlippedDateKey(plannedDate);
  final earliest = _earlier(due, planned);
  if (earliest == null) return null;
  final days = utcDayOf(today).difference(utcDayOf(earliest)).inDays;
  return days > 0 ? days : null;
}

DateTime? _earlier(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

/// Local days whose occurrence rows can change when these fields change.
Set<DateTime> slippedAffectedDays({
  String? dueDate,
  String? plannedDate,
  String? plannedStart,
}) {
  final days = <DateTime>{};
  for (final key in [dueDate, plannedDate]) {
    final day = parseSlippedDateKey(key);
    if (day != null) days.add(localDayOf(day));
  }
  final start = parseSlippedLocalIso(plannedStart);
  if (start != null) days.add(localDayOf(start));
  return days;
}

/// Moves a date key to [targetDay]. Invalid values are preserved.
String? shiftDateKeyToDay(String? value, DateTime targetDay) {
  if (value == null) return null;
  if (parseSlippedDateKey(value) == null) return value;
  return dateKey(targetDay);
}

/// Moves a local ISO value to [targetDay] keeping its wall-clock time.
/// Invalid values are preserved rather than silently rewritten.
String? shiftLocalIsoToDay(String? value, DateTime targetDay) {
  if (value == null) return null;
  final parsed = parseSlippedLocalIso(value);
  if (parsed == null) return value;
  return formatLocalIso(
    DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      parsed.hour,
      parsed.minute,
    ),
  );
}

String formatLocalIso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}T'
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

DateTime nextLocalDay(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1);
