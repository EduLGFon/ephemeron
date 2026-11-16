/// Pure command parser for the Stream command palette.
library;

import 'command_request.dart';
import '../stream_route_params.dart';

enum StreamLocaleOrModeResolver { en, pt }

CommandRequest parseCommand(
  String input, {
  required DateTime now,
  StreamLocaleOrModeResolver? locale,
  StreamLocaleOrModeResolver? resolver,
  StreamLocaleOrModeResolver? mode,
  StreamLocaleOrModeResolver? localeResolver,
}) {
  final loc =
      locale ??
      resolver ??
      mode ??
      localeResolver ??
      StreamLocaleOrModeResolver.en;
  var text = input.trim();
  if (text.startsWith('>')) text = text.substring(1).trim();
  if (text.isEmpty) return const NoneCommand('');

  final lower = text.toLowerCase();
  final parts = lower.split(RegExp(r'\s+'));
  final restOriginal = text.substring(parts.first.length).trim();
  // helper to get rest preserving case from original text
  // go to <date>
  if (parts.first == 'go' && parts.length >= 3 && parts[1] == 'to') {
    final dateText = text.substring(lower.indexOf('to') + 2).trim();
    final d = _parseDate(dateText, now, loc);
    if (d != null) return GoToDateCommand(d);
    return UnknownCommand(text);
  }
  if (loc == StreamLocaleOrModeResolver.pt &&
      parts.first == 'ir' &&
      parts.length >= 3 &&
      parts[1] == 'para') {
    final dateText = text.substring(lower.indexOf('para') + 4).trim();
    final d = _parseDate(dateText, now, loc);
    if (d != null) return GoToDateCommand(d);
    return UnknownCommand(text);
  }

  // zoom <level>
  if (parts.first == 'zoom' && parts.length >= 2) {
    const levels = {'hour', 'day', 'week', 'month', 'year'};
    if (levels.contains(parts[1])) {
      return ZoomCommand(parts[1]);
    }
    return UnknownCommand(text);
  }

  // focus / start focus
  if (parts.first == 'focus' && parts.length >= 2) {
    final m = int.tryParse(parts[1]);
    if (m != null) return StartFocusCommand(m);
    return UnknownCommand(text);
  }
  if (parts.first == 'start' && parts.length >= 3 && parts[1] == 'focus') {
    final m = int.tryParse(parts[2]);
    if (m != null) return StartFocusCommand(m);
    return UnknownCommand(text);
  }
  if (loc == StreamLocaleOrModeResolver.pt &&
      parts.first == 'focar' &&
      parts.length >= 2) {
    final m = int.tryParse(parts[1]);
    if (m != null) return StartFocusCommand(m);
    return UnknownCommand(text);
  }

  // complete <title>
  if (parts.first == 'complete' && restOriginal.isNotEmpty) {
    return CompleteCommand(restOriginal);
  }
  // search <text>
  if (parts.first == 'search' && restOriginal.isNotEmpty) {
    return SearchCommand(restOriginal);
  }

  // theme
  if (parts.first == 'theme' && parts.length >= 2) {
    const modes = {'light', 'dark', 'trueblack', 'system'};
    if (modes.contains(parts[1])) return ThemeCommand(parts[1]);
    return UnknownCommand(text);
  }
  if (loc == StreamLocaleOrModeResolver.pt &&
      parts.first == 'tema' &&
      parts.length >= 2) {
    const modes = {'light', 'dark', 'trueblack', 'system'};
    if (modes.contains(parts[1])) return ThemeCommand(parts[1]);
    return UnknownCommand(text);
  }

  // bare commands
  if (lower == 'agenda') return const AgendaCommand();
  if (lower == 'settings') return const SettingsCommand();
  if (lower == 'help' ||
      (loc == StreamLocaleOrModeResolver.pt && lower == 'ajuda')) {
    return const HelpCommand();
  }
  if (lower == 'sync' || lower == 'sync now') return const SyncNowCommand();

  // complete/search with pt? keep documented only en keywords above.

  return UnknownCommand(text);
}

DateTime? _parseDate(String raw, DateTime now, StreamLocaleOrModeResolver loc) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final iso = tryParseStreamDate(t);
  if (iso != null) return iso;
  final l = t.toLowerCase();
  if (l == 'today' || (loc == StreamLocaleOrModeResolver.pt && l == 'hoje')) {
    return DateTime(now.year, now.month, now.day);
  }
  if (l == 'tomorrow' ||
      (loc == StreamLocaleOrModeResolver.pt && l == 'amanha') ||
      l == 'amanhã') {
    final d = now.add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day);
  }
  // weekday table
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
  if (loc == StreamLocaleOrModeResolver.pt) {
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
