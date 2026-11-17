import 'countdown_landmark_item.dart';

/// Formatter-agnostic position of a countdown relative to "now".
enum CountdownLandmarkKind { past, today, future, invalid }

/// Whole-day difference between [item]'s target date and [now] in local
/// calendar days (not 24-hour buckets; DST-safe). Returns null when the item
/// has no valid target date, so the caller can skip it.
int? daysUntil(CountdownLandmarkItem item, DateTime now) {
  final target = _targetDate(item);
  if (target == null) return null;
  final utcTarget = DateTime.utc(target.year, target.month, target.day);
  final utcToday = DateTime.utc(now.year, now.month, now.day);
  return utcTarget.difference(utcToday).inDays;
}

/// Convenience classifier for [item] relative to [now].
CountdownLandmarkKind countdownLandmarkKind(
  CountdownLandmarkItem item,
  DateTime now,
) {
  final d = daysUntil(item, now);
  if (d == null) return CountdownLandmarkKind.invalid;
  if (d < 0) return CountdownLandmarkKind.past;
  if (d == 0) return CountdownLandmarkKind.today;
  return CountdownLandmarkKind.future;
}

DateTime? _targetDate(CountdownLandmarkItem item) {
  final key = item.targetDayKey;
  if (key != null) {
    final parts = key.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null && _validDate(y, m, d)) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }
  final ms = item.targetMs;
  if (ms != null) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime(dt.year, dt.month, dt.day);
  }
  return null;
}

bool _validDate(int year, int month, int day) {
  if (month < 1 || month > 12) return false;
  final lastDay = DateTime(year, month + 1, 0).day;
  if (day < 1 || day > lastDay) return false;
  return true;
}
