import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../../../core/ui/app_sheet.dart';
import '../application/stream_theme_provider.dart';
import '../design/stream_theme.dart';
import 'stream_day_body.dart';
import 'stream_header.dart';
import 'stream_layout_mode.dart';
import 'stream_route_params.dart';
import 'surface/stream_launcher.dart';

class StreamScreen extends ConsumerStatefulWidget {
  const StreamScreen({
    super.key,
    this.date,
    this.zoom,
    this.onOpenCommand,
    this.onOpenSettings,
    this.onDateChanged,
    this.onReturnToNow,
    this.syncStatus = StreamSyncStatus.synced,
    this.syncLabel,
  });

  final DateTime? date;
  final String? zoom;
  final VoidCallback? onOpenCommand;
  final VoidCallback? onOpenSettings;
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback? onReturnToNow;
  final StreamSyncStatus syncStatus;
  final String? syncLabel;

  @override
  ConsumerState<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends ConsumerState<StreamScreen> {
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

  Widget _captureTray() =>
      const SizedBox(key: Key('captureTrayPlaceholder'), height: 72);

  Widget _compact(StreamHeader header, StreamDayBody body) => Column(
    children: [
      header,
      Expanded(child: body),
      _captureTray(),
    ],
  );

  Widget _medium(StreamHeader header, StreamDayBody body) => Column(
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
      _captureTray(),
    ],
  );

  Widget _expanded(StreamHeader header, StreamDayBody body) => Row(
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
                _captureTray(),
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
    final header = StreamHeader(
      dateLabel:
          '${DateFormat('EEE d MMM').format(params.date)} '
          '(${formatStreamDate(params.date)})',
      levelLabel: l.streamDay,
      slippedCount: 0,
      onOpenCommand: widget.onOpenCommand,
      menuLabel: l.streamLauncherMenu,
      onOpenMenu: _openLauncher,
      syncStatus: widget.syncStatus,
      syncLabel: widget.syncLabel,
      settingsLabel: l.streamSettings,
      onOpenSettings: _openSettings,
    );
    // TODO(#stream-overlays): wire command palette overlay and openCommand.
    final body = StreamDayBody(
      date: params.date,
      onDateChanged: (day) {
        widget.onDateChanged?.call(day);
        GoRouter.maybeOf(context)?.go('/stream/${formatStreamDate(day)}/day');
      },
      onReturnToNow: widget.onReturnToNow,
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layoutMode = streamLayoutModeForWidth(constraints.maxWidth);
              switch (layoutMode) {
                case StreamLayoutMode.compact:
                  return _compact(header, body);
                case StreamLayoutMode.medium:
                  return _medium(header, body);
                case StreamLayoutMode.expanded:
                  return _expanded(header, body);
              }
            },
          ),
        ),
      ),
    );
  }
}
