/// Pure command parser for the Stream command palette.
library;

import 'command_parser_helpers.dart';
import 'command_request.dart';

enum StreamLocale { en, pt }

/// Parses palette text. `now` is required (no implicit clock). Focus minutes
/// are accepted only in 1..240; out-of-range values yield [UnknownCommand].
/// Unknown results preserve the original input text, including a leading ">".
CommandRequest parseCommand(
  String input, {
  required DateTime now,
  StreamLocale locale = StreamLocale.en,
}) {
  final original = input.trim();
  final stripped = original.startsWith('>')
      ? original.substring(1).trim()
      : original;
  if (stripped.isEmpty) return const NoneCommand('');

  final lower = stripped.toLowerCase();
  final parts = lower.split(RegExp(r'\s+'));
  final head = parts.first;

  if (head == 'go' && parts.length >= 3 && parts[1] == 'to') {
    final d = parseCommandDate(
      stripped.substring(lower.indexOf('to') + 2).trim(),
      now,
      locale == StreamLocale.pt,
    );
    if (d != null) return GoToDateCommand(d);
    return UnknownCommand(original);
  }
  if (locale == StreamLocale.pt &&
      head == 'ir' &&
      parts.length >= 3 &&
      parts[1] == 'para') {
    final d = parseCommandDate(
      stripped.substring(lower.indexOf('para') + 4).trim(),
      now,
      locale == StreamLocale.pt,
    );
    if (d != null) return GoToDateCommand(d);
    return UnknownCommand(original);
  }
  if (head == 'zoom' && parts.length >= 2) {
    const levels = {'hour', 'day', 'week', 'month', 'year'};
    if (levels.contains(parts[1])) return ZoomCommand(parts[1]);
    return UnknownCommand(original);
  }
  if (head == 'focus' && parts.length >= 2) {
    final m = int.tryParse(parts[1]);
    if (m != null && m >= 1 && m <= 240) return StartFocusCommand(m);
    return UnknownCommand(original);
  }
  if (head == 'start' && parts.length >= 3 && parts[1] == 'focus') {
    final m = int.tryParse(parts[2]);
    if (m != null && m >= 1 && m <= 240) return StartFocusCommand(m);
    return UnknownCommand(original);
  }
  if (locale == StreamLocale.pt && head == 'focar' && parts.length >= 2) {
    final m = int.tryParse(parts[1]);
    if (m != null && m >= 1 && m <= 240) return StartFocusCommand(m);
    return UnknownCommand(original);
  }
  if (head == 'complete') {
    final rest = stripped.substring(head.length).trim();
    if (rest.isNotEmpty) return CompleteCommand(rest);
  }
  if (head == 'search') {
    final rest = stripped.substring(head.length).trim();
    if (rest.isNotEmpty) return SearchCommand(rest);
  }
  if (head == 'theme' && parts.length >= 2) {
    const modes = {'light', 'dark', 'trueblack', 'system'};
    if (modes.contains(parts[1])) return ThemeCommand(parts[1]);
    return UnknownCommand(original);
  }
  if (locale == StreamLocale.pt && head == 'tema' && parts.length >= 2) {
    const modes = {'light', 'dark', 'trueblack', 'system'};
    if (modes.contains(parts[1])) return ThemeCommand(parts[1]);
    return UnknownCommand(original);
  }
  if (stripped.toLowerCase() == 'agenda') return const AgendaCommand();
  if (stripped.toLowerCase() == 'settings') return const SettingsCommand();
  if (stripped.toLowerCase() == 'help' ||
      (locale == StreamLocale.pt && stripped.toLowerCase() == 'ajuda')) {
    return const HelpCommand();
  }
  if (stripped.toLowerCase() == 'sync' ||
      stripped.toLowerCase() == 'sync now') {
    return const SyncNowCommand();
  }
  return UnknownCommand(original);
}
