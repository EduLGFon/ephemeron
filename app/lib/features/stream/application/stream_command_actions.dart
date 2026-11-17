/// Maps parsed Stream palette commands to typed surface intents and runs the
/// side-effectful ones. Application layer only: no UI, no routing, no
/// snackbars. The surface owns navigation and user feedback.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/application/sync_providers.dart';
import '../design/stream_theme_mode.dart';
import '../presentation/commands/command_request.dart';
import 'stream_theme_provider.dart';

/// Zoom levels the Stream surface can render. The parser also accepts `hour`
/// and `year`; this unit reports those as unsupported instead of silently
/// dropping the requested level.
const Set<String> _supportedZooms = {'day', 'week', 'month'};

/// Focus control is not mapped in this unit: the repository has no focus
/// pause/resume surface to route to.
const String _focusUnsupported = 'focus pause/resume is not available';

/// Title-based completion is ambiguous (duplicate and recurring titles).
const String _completeUnsupported = 'title-based completion is ambiguous';

/// Typed intent for the Stream surface.
sealed class StreamCommandIntent {
  const StreamCommandIntent();
}

final class StreamCommandGoToDate extends StreamCommandIntent {
  const StreamCommandGoToDate(this.date);
  final DateTime date;
}

final class StreamCommandZoom extends StreamCommandIntent {
  const StreamCommandZoom(this.level);
  final String level;
}

final class StreamCommandAgenda extends StreamCommandIntent {
  const StreamCommandAgenda();
}

final class StreamCommandSettings extends StreamCommandIntent {
  const StreamCommandSettings();
}

final class StreamCommandTheme extends StreamCommandIntent {
  const StreamCommandTheme(this.mode);
  final StreamThemeMode mode;
}

final class StreamCommandHelp extends StreamCommandIntent {
  const StreamCommandHelp();
}

final class StreamCommandSyncNow extends StreamCommandIntent {
  const StreamCommandSyncNow();
}

final class StreamCommandSearch extends StreamCommandIntent {
  const StreamCommandSearch();
}

/// Carries a reason the surface may show to the user.
final class StreamCommandUnsupported extends StreamCommandIntent {
  const StreamCommandUnsupported(this.reason);
  final String reason;
}

/// Pure, deterministic mapping from parser output to a surface intent.
StreamCommandIntent mapStreamCommand(CommandRequest request) =>
    switch (request) {
      NoneCommand() => const StreamCommandUnsupported('empty command'),
      UnknownCommand() => const StreamCommandUnsupported('unknown command'),
      GoToDateCommand(:final dateValue) => StreamCommandGoToDate(dateValue),
      ZoomCommand(:final levelValue) => _zoomIntent(levelValue),
      StartFocusCommand() => const StreamCommandUnsupported(_focusUnsupported),
      CompleteCommand() => const StreamCommandUnsupported(_completeUnsupported),
      SearchCommand() => const StreamCommandSearch(),
      AgendaCommand() => const StreamCommandAgenda(),
      SettingsCommand() => const StreamCommandSettings(),
      SyncNowCommand() => const StreamCommandSyncNow(),
      ThemeCommand(:final modeValue) => _themeIntent(modeValue),
      HelpCommand() => const StreamCommandHelp(),
    };

StreamCommandIntent _zoomIntent(String level) => _supportedZooms.contains(level)
    ? StreamCommandZoom(level)
    : StreamCommandUnsupported('unsupported zoom level "$level"');

StreamCommandIntent _themeIntent(String raw) => switch (raw) {
  'light' => const StreamCommandTheme(StreamThemeMode.light),
  'dark' => const StreamCommandTheme(StreamThemeMode.dark),
  'trueblack' => const StreamCommandTheme(StreamThemeMode.trueBlack),
  'system' => const StreamCommandTheme(StreamThemeMode.system),
  _ => StreamCommandUnsupported('unsupported theme mode "$raw"'),
};

/// Outcome of [StreamCommandExecutor.execute].
sealed class StreamCommandResult {
  const StreamCommandResult();
}

/// Side effect ran; the surface only needs to dismiss the palette.
final class StreamCommandHandled extends StreamCommandResult {
  const StreamCommandHandled();
}

/// The surface must handle this intent (route, date, zoom, help).
final class StreamCommandNavigate extends StreamCommandResult {
  const StreamCommandNavigate(this.intent);
  final StreamCommandIntent intent;
}

/// Typed failure for unsupported commands and side-effect errors.
final class StreamCommandFailed extends StreamCommandResult {
  const StreamCommandFailed(this.reason);
  final String reason;
}

class StreamCommandExecutor {
  StreamCommandExecutor({required this.setThemeMode, required this.syncNow});

  final Future<void> Function(StreamThemeMode mode) setThemeMode;
  final Future<void> Function() syncNow;

  /// Runs theme and sync side effects. Navigation intents are returned to the
  /// caller, which owns routing and focus. Errors become a typed failure; the
  /// exception detail is not echoed to the surface.
  Future<StreamCommandResult> execute(StreamCommandIntent intent) async {
    switch (intent) {
      case StreamCommandTheme(:final mode):
        try {
          await setThemeMode(mode);
          return const StreamCommandHandled();
        } catch (_) {
          return const StreamCommandFailed('theme update failed');
        }
      case StreamCommandSyncNow():
        try {
          await syncNow();
          return const StreamCommandHandled();
        } catch (_) {
          return const StreamCommandFailed('sync failed to start');
        }
      case StreamCommandUnsupported(:final reason):
        return StreamCommandFailed(reason);
      case StreamCommandGoToDate() ||
          StreamCommandZoom() ||
          StreamCommandAgenda() ||
          StreamCommandSettings() ||
          StreamCommandSearch() ||
          StreamCommandHelp():
        return StreamCommandNavigate(intent);
    }
  }
}

/// Executor wired to the app notifiers. Tests override the theme and sync
/// providers, or this provider with a fake executor.
final streamCommandExecutorProvider = Provider<StreamCommandExecutor>((ref) {
  return StreamCommandExecutor(
    setThemeMode: (mode) =>
        ref.read(streamThemeProvider.notifier).setMode(mode),
    syncNow: () => ref.read(syncStatusProvider.notifier).syncNow(),
  );
});
