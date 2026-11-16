// Pure countdown display helpers shared by the list screen and entity links.
import '../../../domain/countdowns/countdown.dart';

/// Parses a stored `YYYY-MM-DD` key. Invalid or empty values mean no date.
DateTime? parseCountdownDate(String? targetDate) {
  if (targetDate == null || targetDate.isEmpty) return null;
  final p = targetDate.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(y, m, d);
}

/// Large left-side badge text. Null means the countdown has no date.
String countdownDayBadge(int? days) {
  if (days == null) return '-';
  if (days < 0) return 'Past';
  return '$days';
}

String countdownRelativeLabel(int days) {
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days > 1) return 'in $days days';
  if (days == -1) return 'yesterday';
  return '${-days} days ago';
}

/// Resolves the next occurrence and whole-day distance for one countdown.
({DateTime next, int days})? countdownSchedule({
  required String? targetDate,
  required bool yearlyRepeat,
  DateTime? today,
}) {
  final parsed = parseCountdownDate(targetDate);
  if (parsed == null) return null;
  final now = today ?? DateTime.now();
  // One-time countdowns use the full stored date; yearly ones roll to the
  // next occurrence via the domain helper.
  final next = yearlyRepeat
      ? countdownNextDate(
          month: parsed.month,
          day: parsed.day,
          today: now,
          yearlyRepeat: true,
        )
      : DateTime(parsed.year, parsed.month, parsed.day);
  return (next: next, days: daysUntil(next, now));
}

/// Human label for a local countdown link, or null when unlinked/unknown.
String? countdownLinkedTypeLabel(String? type) {
  switch (type) {
    case 'event':
      return 'Event';
    case 'task':
      return 'Task';
    case 'habit':
      return 'Habit';
    default:
      return null;
  }
}
