// Pure helper that decorates an alarm/reminder title with relative
// date/time context so a notification is not mistaken for "now".
// Pure Dart, no Flutter imports. Clock is injectable for tests.
String decorateAlarmTitle(
  String title,
  int fireAtUtcMs, {
  DateTime? now,
  int? nowUtcMs,
  bool allDay = false,
  bool includeDayLabel = true,
}) {
  final fireLocal = DateTime.fromMillisecondsSinceEpoch(
    fireAtUtcMs,
    isUtc: true,
  ).toLocal();
  DateTime nowLocal;
  if (nowUtcMs != null) {
    nowLocal = DateTime.fromMillisecondsSinceEpoch(
      nowUtcMs,
      isUtc: true,
    ).toLocal();
  } else if (now != null) {
    nowLocal = now.isUtc ? now.toLocal() : now;
  } else {
    nowLocal = DateTime.now();
  }

  final fireDate = DateTime(fireLocal.year, fireLocal.month, fireLocal.day);
  final todayDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final diff = fireDate.difference(todayDate).inDays;

  final timePart = allDay
      ? ''
      : ' ${fireLocal.hour.toString().padLeft(2, '0')}:'
            '${fireLocal.minute.toString().padLeft(2, '0')}';

  String dayPart = '';
  if (includeDayLabel) {
    if (diff == 0) {
      dayPart = allDay ? ' Today' : '';
    } else if (diff == 1) {
      dayPart = ' Tomorrow';
    } else if (diff == -1) {
      dayPart = ' Yesterday';
    } else if (diff > 1 && diff < 7) {
      dayPart = ' ${_weekdayShort(fireLocal.weekday)}';
    } else {
      dayPart = ' ${fireLocal.day}/${fireLocal.month}';
    }
  }

  final suffix = (timePart + dayPart).trim();
  final base = title.trim();
  if (suffix.isEmpty) return base;
  if (base.isEmpty) return suffix;
  if (base.endsWith(suffix)) return base;
  return '$base $suffix';
}

/// Strips a previously appended relative date/time suffix.
String stripAlarmTitleSuffix(String title) {
  var out = title.trimRight();
  for (var i = 0; i < 3; i++) {
    final m = RegExp(
      r' (?:\d{2}:\d{2}|Tomorrow|Yesterday|Today|Mon|Tue|Wed|Thu|Fri|Sat|Sun|\d{1,2}/\d{1,2})$',
    ).firstMatch(out);
    if (m == null) break;
    out = out.substring(0, m.start);
  }
  return out.trimRight();
}

String _weekdayShort(int weekday) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[(weekday - 1).clamp(0, 6)];
}
