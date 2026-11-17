/// Localized labels and candidate table for the Stream command overlay. Pure
/// presentation data: each candidate maps to an application intent.
library;

import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../application/stream_command_actions.dart';
import '../../design/stream_theme_mode.dart';
import '../commands/command_palette.dart' show CommandCandidate;

/// Localized strings the overlay needs. Built from [AppLocalizations] by the
/// screen; tests may pass explicit labels.
class StreamCommandOverlayLabels {
  const StreamCommandOverlayLabels({
    required this.title,
    required this.hint,
    required this.empty,
    required this.close,
    required this.today,
    required this.tomorrow,
    required this.settings,
    required this.search,
    required this.syncNow,
    required this.themeLight,
    required this.themeDark,
    required this.themeTrueBlack,
    required this.themeSystem,
  });

  factory StreamCommandOverlayLabels.of(AppLocalizations l) {
    return StreamCommandOverlayLabels(
      title: l.streamCommandPaletteTitle,
      hint: l.streamCommandPaletteHint,
      empty: l.streamCommandPaletteEmpty,
      close: l.streamCommandPaletteClose,
      today: l.streamCommandToday,
      tomorrow: l.streamCommandTomorrow,
      settings: l.streamCommandSettings,
      search: l.streamCommandSearch,
      syncNow: l.streamCommandSyncNow,
      themeLight: l.streamCommandThemeLight,
      themeDark: l.streamCommandThemeDark,
      themeTrueBlack: l.streamCommandThemeTrueBlack,
      themeSystem: l.streamCommandThemeSystem,
    );
  }

  final String title;
  final String hint;
  final String empty;
  final String close;
  final String today;
  final String tomorrow;
  final String settings;
  final String search;
  final String syncNow;
  final String themeLight;
  final String themeDark;
  final String themeTrueBlack;
  final String themeSystem;
}

/// Palette row plus the intent it runs. Keeping the mapping typed avoids
/// parsing localized labels back into commands.
class StreamCommandEntry {
  const StreamCommandEntry({required this.candidate, required this.intent});

  final CommandCandidate candidate;
  final StreamCommandIntent intent;
}

/// Today, Tomorrow, Settings, Search, Sync now and the four theme modes.
List<StreamCommandEntry> buildStreamCommandEntries({
  required DateTime now,
  required StreamCommandOverlayLabels labels,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return [
    StreamCommandEntry(
      candidate: CommandCandidate(id: 'today', label: labels.today),
      intent: StreamCommandGoToDate(today),
    ),
    StreamCommandEntry(
      candidate: CommandCandidate(id: 'tomorrow', label: labels.tomorrow),
      intent: StreamCommandGoToDate(tomorrow),
    ),
    StreamCommandEntry(
      candidate: CommandCandidate(id: 'settings', label: labels.settings),
      intent: const StreamCommandSettings(),
    ),
    StreamCommandEntry(
      candidate: CommandCandidate(id: 'search', label: labels.search),
      intent: const StreamCommandSearch(),
    ),
    StreamCommandEntry(
      candidate: CommandCandidate(id: 'syncNow', label: labels.syncNow),
      intent: const StreamCommandSyncNow(),
    ),
    StreamCommandEntry(
      candidate: CommandCandidate(id: 'themeLight', label: labels.themeLight),
      intent: const StreamCommandTheme(StreamThemeMode.light),
    ),
    StreamCommandEntry(
      candidate: CommandCandidate(id: 'themeDark', label: labels.themeDark),
      intent: const StreamCommandTheme(StreamThemeMode.dark),
    ),
    StreamCommandEntry(
      candidate: CommandCandidate(
        id: 'themeTrueBlack',
        label: labels.themeTrueBlack,
      ),
      intent: const StreamCommandTheme(StreamThemeMode.trueBlack),
    ),
    StreamCommandEntry(
      candidate: CommandCandidate(id: 'themeSystem', label: labels.themeSystem),
      intent: const StreamCommandTheme(StreamThemeMode.system),
    ),
  ];
}
