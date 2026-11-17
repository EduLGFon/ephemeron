import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../../../core/ui/app_feedback.dart';
import '../../../../core/ui/app_sheet.dart';
import '../application/stream_command_actions.dart';
import '../application/stream_day_cache_scope.dart';
import '../application/stream_day_providers.dart' show StreamDayKey;
import '../application/stream_sync_status.dart';
import '../application/stream_theme_provider.dart';
import '../capture/capture_parser.dart' show CaptureLocale;
import '../design/stream_theme.dart';
import 'stream_day_body.dart';
import 'stream_header.dart';
import 'stream_layout_mode.dart';
import 'stream_route_params.dart';
import 'surface/stream_command_overlay.dart';
import 'surface/stream_dock_host.dart';
import 'surface/stream_launcher.dart';

class StreamScreen extends ConsumerStatefulWidget {
  const StreamScreen({
    super.key,
    this.date,
    this.zoom,
    this.now,
    this.onOpenCommand,
    this.onOpenSettings,
    this.onDateChanged,
    this.onReturnToNow,
    this.syncStatus,
    this.syncLabel,
  });

  final DateTime? date;
  final String? zoom;

  /// Fixed wall clock for tests; null uses the real clock.
  final DateTime? now;
  final VoidCallback? onOpenCommand;
  final VoidCallback? onOpenSettings;
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback? onReturnToNow;

  /// Test overrides. Null uses the live combined sync status and its localized
  /// label; a provided status without a label keeps the header label empty.
  final StreamSyncStatus? syncStatus;
  final String? syncLabel;

  @override
  ConsumerState<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends ConsumerState<StreamScreen> {
  final ValueNotifier<bool> _paletteOpen = ValueNotifier<bool>(false);
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'streamShortcuts');

  @override
  void dispose() {
    _paletteOpen.dispose();
    _shortcutFocus.dispose();
    super.dispose();
  }

  void _openPalette() {
    _paletteOpen.value = true;
  }

  void _closePalette() {
    _paletteOpen.value = false;
    _shortcutFocus.requestFocus();
  }

  void _onBreadcrumbTap() {
    widget.onOpenCommand?.call();
    _openPalette();
  }

  /// Routes navigation intents and runs side-effect intents through the shared
  /// executor. Failures use a localized snackbar; the reason stays internal.
  Future<void> _handleCommandIntent(StreamCommandIntent intent) async {
    final router = GoRouter.maybeOf(context);
    switch (intent) {
      case StreamCommandGoToDate(:final date):
        router?.go('/stream/${formatStreamDate(date)}/day');
      case StreamCommandSettings():
        router?.push('/settings');
      case StreamCommandSearch():
        router?.push('/search');
      case StreamCommandSyncNow() || StreamCommandTheme():
        final result = await ref
            .read(streamCommandExecutorProvider)
            .execute(intent);
        if (!mounted || result is! StreamCommandFailed) return;
        showErrorSnackBar(
          context,
          AppLocalizations.of(context).streamCommandFailed,
        );
      case StreamCommandZoom() ||
          StreamCommandAgenda() ||
          StreamCommandHelp() ||
          StreamCommandUnsupported():
        // Not offered by the palette.
        break;
    }
  }

  String _syncLabel(AppLocalizations l, StreamSyncStatus status) =>
      switch (status) {
        StreamSyncStatus.synced => l.streamSyncSynced,
        StreamSyncStatus.syncing => l.streamSyncSyncing,
        StreamSyncStatus.offline => l.streamSyncOffline,
        StreamSyncStatus.attention => l.streamSyncAttention,
      };

  StreamRouteParams _resolveParams() {
    final router = GoRouter.maybeOf(context);
    final gs = router?.state;
    final routeDate = gs == null
        ? null
        : tryParseStreamDate(gs.pathParameters['date']);
    final routeZoom = gs?.pathParameters['zoom'];
    final resolvedDate = widget.date ?? routeDate;
    final resolvedZoom = widget.zoom ?? routeZoom;
    return parseStreamRouteParams(
      date: resolvedDate == null ? null : formatStreamDate(resolvedDate),
      zoom: resolvedZoom,
    );
  }

  void _openSettings() {
    widget.onOpenSettings?.call();
    GoRouter.maybeOf(context)?.go('/settings');
  }

  void _openLauncher() {
    showAppSheet<void>(
      context,
      builder: (sheetContext) => StreamLauncher(
        onClose: () => Navigator.of(sheetContext).pop(),
        onSelected: (destination) {
          Navigator.of(sheetContext).pop();
          _goToDestination(destination);
        },
      ),
    );
  }

  /// Shell branches use `go` because pushing a branch would mount a second
  /// AppShell. Top-level screens push so the Stream stays on the back stack.
  void _goToDestination(StreamLauncherDestination destination) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (destination.keepsStreamOnStack) {
      router.push(destination.route);
    } else {
      router.go(destination.route);
    }
  }

  CaptureLocale _captureLocale(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'pt'
      ? CaptureLocale.pt
      : CaptureLocale.en;

  Widget _compact(Widget header, Widget body, Widget dock) => Column(
    children: [
      header,
      Expanded(child: body),
      dock,
    ],
  );

  Widget _medium(Widget header, Widget body, Widget dock) => Column(
    children: [
      header,
      Expanded(
        child: Row(
          children: [
            Expanded(child: body),
            const SizedBox(key: Key('sidePanelPlaceholder'), width: 200),
          ],
        ),
      ),
      dock,
    ],
  );

  Widget _expanded(Widget header, Widget body, Widget dock) => Row(
    children: [
      const SizedBox(key: Key('leftPanelPlaceholder'), width: 240),
      Expanded(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                header,
                Expanded(child: body),
                dock,
              ],
            ),
          ),
        ),
      ),
      const SizedBox(key: Key('rightInspectorPlaceholder'), width: 320),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final params = _resolveParams();
    final mode = ref.watch(streamThemeProvider);
    final brightness = MediaQuery.platformBrightnessOf(context);
    final theme = streamThemeData(mode, brightness);
    final l = AppLocalizations.of(context);
    final now = widget.now ?? DateTime.now();
    final StreamSyncStatus syncStatus =
        widget.syncStatus ?? ref.watch(streamSyncStatusProvider);
    final syncLabel =
        widget.syncLabel ??
        (widget.syncStatus == null ? _syncLabel(l, syncStatus) : null);
    final header = Semantics(
      container: true,
      explicitChildNodes: true,
      child: StreamHeader(
        dateLabel:
            '${DateFormat('EEE d MMM').format(params.date)} '
            '(${formatStreamDate(params.date)})',
        levelLabel: l.streamDay,
        slippedCount: 0,
        onOpenCommand: _onBreadcrumbTap,
        menuLabel: l.streamLauncherMenu,
        onOpenMenu: _openLauncher,
        syncStatus: syncStatus,
        syncLabel: syncLabel,
        settingsLabel: l.streamSettings,
        onOpenSettings: _openSettings,
      ),
    );
    final body = StreamDayCacheScope(
      day: StreamDayKey(
        year: params.date.year,
        month: params.date.month,
        day: params.date.day,
      ),
      child: StreamDayBody(
        date: params.date,
        now: now,
        onDateChanged: (day) {
          widget.onDateChanged?.call(day);
          GoRouter.maybeOf(context)?.go('/stream/${formatStreamDate(day)}/day');
        },
        onReturnToNow: widget.onReturnToNow,
      ),
    );
    final dock = StreamDockHost(now: now, locale: _captureLocale(context));

    return Theme(
      data: theme,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              _openPalette,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
              _openPalette,
        },
        child: Focus(
          focusNode: _shortcutFocus,
          autofocus: true,
          includeSemantics: false,
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Stack(
              children: [
                SafeArea(
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final layoutMode = streamLayoutModeForWidth(
                          constraints.maxWidth,
                        );
                        switch (layoutMode) {
                          case StreamLayoutMode.compact:
                            return _compact(header, body, dock);
                          case StreamLayoutMode.medium:
                            return _medium(header, body, dock);
                          case StreamLayoutMode.expanded:
                            return _expanded(header, body, dock);
                        }
                      },
                    ),
                  ),
                ),
                StreamCommandOverlay(
                  open: _paletteOpen,
                  now: now,
                  labels: StreamCommandOverlayLabels.of(l),
                  onClose: _closePalette,
                  onSelected: (intent) =>
                      unawaited(_handleCommandIntent(intent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
