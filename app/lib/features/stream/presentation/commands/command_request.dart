/// Immutable result model for Stream command-palette commands. Pure Dart.
library;

enum CommandKind {
  none,
  unknown,
  goToDate,
  zoom,
  startFocus,
  complete,
  search,
  agenda,
  settings,
  syncNow,
  theme,
  help,
}

sealed class CommandRequest {
  const CommandRequest(this.kind);

  final CommandKind kind;

  DateTime? get date => null;
  String? get level => null;
  int? get minutes => null;
  String? get title => null;
  String? get text => null;
  String? get mode => null;
  String? get raw => null;
}

final class NoneCommand extends CommandRequest {
  const NoneCommand([this.rawText = '']) : super(CommandKind.none);
  final String rawText;
  @override
  String? get raw => rawText;
}

final class UnknownCommand extends CommandRequest {
  const UnknownCommand([this.rawText = '']) : super(CommandKind.unknown);
  final String rawText;
  @override
  String? get raw => rawText;
}

final class GoToDateCommand extends CommandRequest {
  const GoToDateCommand(this.dateValue) : super(CommandKind.goToDate);
  final DateTime dateValue;
  @override
  DateTime? get date => dateValue;
}

final class ZoomCommand extends CommandRequest {
  const ZoomCommand(this.levelValue) : super(CommandKind.zoom);
  final String levelValue;
  @override
  String? get level => levelValue;
}

final class StartFocusCommand extends CommandRequest {
  const StartFocusCommand(this.minutesValue) : super(CommandKind.startFocus);
  final int minutesValue;
  @override
  int? get minutes => minutesValue;
}

final class CompleteCommand extends CommandRequest {
  const CompleteCommand(this.titleValue) : super(CommandKind.complete);
  final String titleValue;
  @override
  String? get title => titleValue;
}

final class SearchCommand extends CommandRequest {
  const SearchCommand(this.textValue) : super(CommandKind.search);
  final String textValue;
  @override
  String? get text => textValue;
}

final class AgendaCommand extends CommandRequest {
  const AgendaCommand() : super(CommandKind.agenda);
}

final class SettingsCommand extends CommandRequest {
  const SettingsCommand() : super(CommandKind.settings);
}

final class SyncNowCommand extends CommandRequest {
  const SyncNowCommand() : super(CommandKind.syncNow);
}

final class ThemeCommand extends CommandRequest {
  const ThemeCommand(this.modeValue) : super(CommandKind.theme);
  final String modeValue;
  @override
  String? get mode => modeValue;
}

final class HelpCommand extends CommandRequest {
  const HelpCommand() : super(CommandKind.help);
}
