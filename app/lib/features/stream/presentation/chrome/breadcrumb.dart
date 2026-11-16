import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// A tappable date + level label. Shows an optional slipped-count badge.
class Breadcrumb extends StatefulWidget {
  const Breadcrumb({
    super.key,
    required this.dateLabel,
    required this.levelLabel,
    this.slippedCount,
    this.slippedSemanticLabel,
    this.onTap,
  });

  final String dateLabel;
  final String levelLabel;
  final int? slippedCount;
  final String? slippedSemanticLabel;
  final VoidCallback? onTap;

  @override
  State<Breadcrumb> createState() => _BreadcrumbState();
}

class _BreadcrumbState extends State<Breadcrumb> {
  bool _hovered = false;
  bool _focused = false;

  bool get _disabled => widget.onTap == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = _disabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : scheme.onSurface;
    return Semantics(
      button: true,
      enabled: !_disabled,
      label: '${widget.dateLabel}, ${widget.levelLabel}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(StreamRadii.sm),
              focusColor: scheme.primary.withValues(alpha: 0.12),
              hoverColor: scheme.primary.withValues(alpha: 0.06),
              child: AnimatedContainer(
                duration: StreamMotion.fast,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: StreamSpacing.x2,
                  vertical: StreamSpacing.x1,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(StreamRadii.sm),
                  border: _focused
                      ? Border.all(color: scheme.primary, width: 2)
                      : null,
                  color: _hovered
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: StreamTypeScale.sm,
                        fontWeight: FontWeight(StreamFontWeight.medium),
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: StreamSpacing.x1),
                    Text(
                      widget.levelLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: StreamTypeScale.xs,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.slippedCount != null) ...[
                      const SizedBox(width: StreamSpacing.x1),
                      Semantics(
                        label: widget.slippedSemanticLabel,
                        child: Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: StreamSpacing.x1,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(
                              StreamRadii.full,
                            ),
                          ),
                          child: Text(
                            '${widget.slippedCount}',
                            style: TextStyle(
                              fontSize: StreamTypeScale.xs,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
