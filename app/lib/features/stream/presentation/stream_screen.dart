import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../application/stream_theme_provider.dart';
import '../design/stream_theme.dart';
import 'stream_day_body.dart';
import 'stream_header.dart';
import 'stream_layout_mode.dart';
import 'stream_route_params.dart';

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
    DateTime? routeDate;
    String? routeZoom;
    try {
      final gs = GoRouterState.of(context);
      routeDate = tryParseStreamDate(gs.pathParameters['date']);
      routeZoom = gs.pathParameters['zoom'];
    } catch (_) {}
    final resolvedDate = widget.date ?? routeDate;
    final resolvedZoom = widget.zoom ?? routeZoom;
    return parseStreamRouteParams(
      date: resolvedDate == null ? null : formatStreamDate(resolvedDate),
      zoom: resolvedZoom,
    );
  }

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
      levelLabel: params.zoom == 'day' ? l.streamDay : params.zoom,
      slippedCount: 0,
      onOpenCommand: widget.onOpenCommand,
      syncStatus: widget.syncStatus,
      syncLabel: widget.syncLabel,
      onOpenSettings: widget.onOpenSettings,
    );
    final body = StreamDayBody(
      date: params.date,
      onDateChanged: widget.onDateChanged,
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
                  return Column(
                    children: [
                      header,
                      Expanded(child: body),
                      Container(
                        key: const Key('captureTrayPlaceholder'),
                        height: 72,
                      ),
                    ],
                  );
                case StreamLayoutMode.medium:
                  return Column(
                    children: [
                      header,
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: body),
                            Container(
                              key: const Key('sidePanelPlaceholder'),
                              width: 200,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        key: const Key('captureTrayPlaceholder'),
                        height: 72,
                      ),
                    ],
                  );
                case StreamLayoutMode.expanded:
                  return Row(
                    children: [
                      Container(
                        key: const Key('leftPanelPlaceholder'),
                        width: 240,
                      ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              children: [
                                header,
                                Expanded(child: body),
                                Container(
                                  key: const Key('captureTrayPlaceholder'),
                                  height: 72,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        key: const Key('rightInspectorPlaceholder'),
                        width: 320,
                      ),
                    ],
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}
