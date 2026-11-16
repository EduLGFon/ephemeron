/// Pure command parser for the Stream command palette.
library;

import 'command_parser_helpers.dart';
import 'command_request.dart';

enum StreamLocaleOrModeResolver { en, pt }

/// Parses palette text. `now` is required (no implicit clock). Minutes are
/// clamped to 1..240; out-of-range focus values yield [UnknownCommand].
CommandRequest parseCommand(
  String input, {
  required DateTime now,
  StreamLocaleOrModeResolver locale = StreamLocaleOrModeResolver.en,
}) {
  final text = input.trim();
  final stripped = text.startsWith('>') ? text.substring(1).trim() : text;
  if (stripped.isEmpty) return const NoneCommand('');

  final lower = stripped.toLowerCase();
  final parts = lower.split(RegExp(r'\s+'));
  final head = parts.first;

  if (head == 'go' && parts.length >= 3 && parts[1] == 'to') {
    final d = parseCommandDate(
      stripped.substring(lower.indexOf('to') + 2).trim(),
      now,
      locale == StreamLocaleOrModeResolver.pt,
    );
    if (d != null) return GoToDateCommand(d);
    return UnknownCommand(stripped);
  }
  if (locale == StreamLocaleOrModeResolver.pt &&
      head == 'ir' &&
      parts.length >= 3 &&
      parts[1] == 'para') {
    final d = parseCommandDate(
      stripped.substring(lower.indexOf('para') + 4).trim(),
      now,
      locale == StreamLocaleOrModeResolver.pt,
    );
    if (d != null) return GoToDateCommand(d);
    return UnknownCommand(stripped);
  }
  if (head == 'zoom' && parts.length >= 2) {
    const levels = {'hour', 'day', 'week', 'month', 'year'};
    if (levels.contains(parts[1])) return ZoomCommand(parts[1]);
    return UnknownCommand(stripped);
  }
  if (head == 'focus' && parts.length >= 2) {
    final m = int.tryParse(parts[1]);
    if (m != null && m >= 1 && m <= 240) return StartFocusCommand(m);
    return UnknownCommand(stripped);
  }
  if (head == 'start' && parts.length >= 3 && parts[1] == 'focus') {
    final m = int.tryParse(parts[2]);
    if (m != null && m >= 1 && m <= 240) return StartFocusCommand(m);
    return UnknownCommand(stripped);
  }
  if (locale == StreamLocaleOrModeResolver.pt &&
      head == 'focar' &&
      parts.length >= 2) {
    final m = int.tryParse(parts[1]);
    if (m != null && m >= 1 && m <= 240) return StartFocusCommand(m);
    return UnknownCommand(stripped);
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
    return UnknownCommand(stripped);
  }
  if (locale == StreamLocaleOrModeResolver.pt &&
      head == 'tema' &&
      parts.length >= 2) {
    const modes = {'light', 'dark', 'trueblack', 'system'};
    if (modes.contains(parts[1])) return ThemeCommand(parts[1]);
    return UnknownCommand(stripped);
  }
  if (stripped.toLowerCase() == 'agenda') return const AgendaCommand();
  if (stripped.toLowerCase() == 'settings') return const SettingsCommand();
  if (stripped.toLowerCase() == 'help' ||
      (locale == StreamLocaleOrModeResolver.pt &&
          stripped.toLowerCase() == 'ajuda')) {
    return const HelpCommand();
  }
  if (stripped.toLowerCase() == 'sync' ||
      stripped.toLowerCase() == 'sync now') {
    return const SyncNowCommand();
  }
  return UnknownCommand(stripped);
}
