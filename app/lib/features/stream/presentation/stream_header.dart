import 'package:material_ui/material_ui.dart';

import '../design/stream_tokens.dart';
import 'chrome/breadcrumb.dart';

/// Caller-facing sync states for the Stream header dot.
enum StreamSyncStatus { synced, syncing, offline, attention }

/// Header for the Stream surface: breadcrumb + sync dot + avatar. No app bar.
class StreamHeader extends StatelessWidget {
  const StreamHeader({
    super.key,
    required this.dateLabel,
    required this.levelLabel,
    this.slippedCount = 0,
    this.slippedSemanticLabel,
    this.onOpenCommand,
    this.syncStatus = StreamSyncStatus.synced,
    this.syncLabel,
    this.settingsLabel,
    this.settingsTooltip,
    this.onOpenSettings,
  });

  final String dateLabel;
  final String levelLabel;
  final int slippedCount;
  final String? slippedSemanticLabel;
  final VoidCallback? onOpenCommand;
  final StreamSyncStatus syncStatus;
  final String? syncLabel;
  final String? settingsLabel;
  final String? settingsTooltip;
  final VoidCallback? onOpenSettings;

  Color _dotColor(ColorScheme scheme) {
    switch (syncStatus) {
      case StreamSyncStatus.synced:
        return scheme.tertiary;
      case StreamSyncStatus.syncing:
        return scheme.primary;
      case StreamSyncStatus.offline:
        return scheme.outline;
      case StreamSyncStatus.attention:
        return scheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: StreamSpacing.x4,
        vertical: StreamSpacing.x2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Breadcrumb(
              dateLabel: dateLabel,
              levelLabel: levelLabel,
              slippedCount: slippedCount > 0 ? slippedCount : null,
              slippedSemanticLabel: slippedSemanticLabel,
              onTap: onOpenCommand,
            ),
          ),
          const SizedBox(width: StreamSpacing.x2),
          Semantics(
            label: syncLabel,
            child: Container(
              width: StreamIconSize.sm,
              height: StreamIconSize.sm,
              decoration: BoxDecoration(
                color: _dotColor(scheme),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: StreamSpacing.x2),
          Semantics(
            button: true,
            label: settingsLabel ?? '',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.account_circle_outlined),
                iconSize: StreamIconSize.lg,
                tooltip: settingsTooltip ?? settingsLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
