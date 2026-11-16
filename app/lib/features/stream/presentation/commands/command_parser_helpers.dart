/// Helpers for command_parser.dart.
library;

import '../stream_route_params.dart';

DateTime? parseCommandDate(String raw, DateTime now, bool isPt) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final iso = tryParseStreamDate(t);
  if (iso != null) return iso;
  final l = t.toLowerCase();
  if (l == 'today' || (isPt && l == 'hoje')) {
    return DateTime(now.year, now.month, now.day);
  }
  if (l == 'tomorrow' || (isPt && (l == 'amanha' || l == 'amanhã'))) {
    final d = now.add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day);
  }
  final weekdays = <String, int>{
    'mon': DateTime.monday,
    'monday': DateTime.monday,
    'tue': DateTime.tuesday,
    'tuesday': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'wednesday': DateTime.wednesday,
    'thu': DateTime.thursday,
    'thursday': DateTime.thursday,
    'fri': DateTime.friday,
    'friday': DateTime.friday,
    'sat': DateTime.saturday,
    'saturday': DateTime.saturday,
    'sun': DateTime.sunday,
    'sunday': DateTime.sunday,
  };
  if (isPt) {
    weekdays.addAll(const {
      'seg': DateTime.monday,
      'segunda': DateTime.monday,
      'ter': DateTime.tuesday,
      'terca': DateTime.tuesday,
      'terça': DateTime.tuesday,
      'qua': DateTime.wednesday,
      'quarta': DateTime.wednesday,
      'qui': DateTime.thursday,
      'quinta': DateTime.thursday,
      'sex': DateTime.friday,
      'sexta': DateTime.friday,
      'sab': DateTime.saturday,
      'sabado': DateTime.saturday,
      'sábado': DateTime.saturday,
      'dom': DateTime.sunday,
      'domingo': DateTime.sunday,
    });
  }
  final wd = weekdays[l];
  if (wd != null) {
    var d = DateTime(now.year, now.month, now.day);
    while (d.weekday != wd) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }
  return null;
}
