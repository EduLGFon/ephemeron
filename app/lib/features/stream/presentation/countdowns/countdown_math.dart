import 'countdown_landmark_item.dart';

/// Formatter-agnostic position of a countdown relative to "now".
enum CountdownLandmarkKind { past, today, future }

/// Whole-day difference between [item]'s target date and [now] in local
/// calendar days (not 24-hour buckets; DST-safe).
int daysUntil(CountdownLandmarkItem item, DateTime now) {
  final target = _targetDate(item, now);
  final today = DateTime(now.year, now.month, now.day);
  return target.difference(today).inDays;
}

/// Convenience classifier for [item] relative to [now].
CountdownLandmarkKind countdownLandmarkKind(
  CountdownLandmarkItem item,
  DateTime now,
) {
  final d = daysUntil(item, now);
  if (d < 0) return CountdownLandmarkKind.past;
  if (d == 0) return CountdownLandmarkKind.today;
  return CountdownLandmarkKind.future;
}

DateTime _targetDate(CountdownLandmarkItem item, DateTime now) {
  final key = item.targetDayKey;
  if (key != null) {
    final parts = key.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        try {
          return DateTime(y, m, d);
        } catch (_) {
          // Fall through to other sources.
        }
      }
    }
  }
  final ms = item.targetMs;
  if (ms != null) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime(dt.year, dt.month, dt.day);
  }
  return DateTime(now.year, now.month, now.day);
}
