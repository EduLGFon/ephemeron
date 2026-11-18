// Compact sync status for app bars and sidebars. Every state has a distinct
// glyph and semantics text, and the syncing arc plays once instead of spinning
// forever.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../ui/app_motion.dart';
import '../tokens.dart';

enum AppSyncState { synced, syncing, offline, attention }

class AppSyncIndicator extends StatelessWidget {
  const AppSyncIndicator({
    super.key,
    required this.state,
    this.onTap,
    this.label,
    this.compact = true,
    this.tooltip,
  });

  final AppSyncState state;
  final VoidCallback? onTap;
  final String? label;
  final bool compact;
  final String? tooltip;

  String get _stateLabel => switch (state) {
    AppSyncState.synced => 'Synced',
    AppSyncState.syncing => 'Syncing',
    AppSyncState.offline => 'Offline',
    AppSyncState.attention => 'Needs attention',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayLabel = label ?? _stateLabel;
    final icon = switch (state) {
      AppSyncState.synced => Icon(
        Icons.check_circle_outline,
        size: DsIcon.sm,
        color: scheme.primary,
      ),
      AppSyncState.syncing => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: AppMotion.duration(context, DsMotion.slow),
        builder: (context, value, child) {
          return SizedBox(
            width: DsIcon.md,
            height: DsIcon.md,
            child: CustomPaint(
              painter: _SyncArcPainter(
                color: scheme.primary,
                rotation: value * math.pi * 2,
              ),
            ),
          );
        },
      ),
      AppSyncState.offline => Icon(
        Icons.cloud_off_outlined,
        size: DsIcon.md,
        color: scheme.onSurfaceVariant,
      ),
      AppSyncState.attention => Icon(
        Icons.warning_amber_rounded,
        size: DsIcon.md,
        color: scheme.error,
      ),
    };

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        icon,
        if (!compact) ...<Widget>[
          const SizedBox(width: DsSpace.x8),
          Flexible(
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: state == AppSyncState.attention
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );

    final onTap = this.onTap;
    Widget body = onTap == null
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 0 : 48),
            child: content,
          )
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(DsRadius.pill),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.x8),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: content,
                  ),
                ),
              ),
            ),
          );

    final message = tooltip;
    if (message != null) {
      body = Tooltip(message: message, child: body);
    }

    return Semantics(
      container: true,
      label: displayLabel,
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(child: body),
    );
  }
}

class _SyncArcPainter extends CustomPainter {
  const _SyncArcPainter({required this.color, required this.rotation});

  final Color color;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      rotation - math.pi / 2,
      math.pi * 1.4,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SyncArcPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.rotation != rotation;
  }
}
