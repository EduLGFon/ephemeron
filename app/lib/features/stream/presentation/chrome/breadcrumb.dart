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
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;

  bool get _disabled => widget.onTap == null;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

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
      excludeSemantics: true,
      label: '${widget.dateLabel}, ${widget.levelLabel}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: InkWell(
            focusNode: _focusNode,
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(StreamRadii.sm),
            focusColor: scheme.primary.withValues(alpha: 0.12),
            hoverColor: scheme.primary.withValues(alpha: 0.06),
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: StreamSpacing.x2,
                vertical: StreamSpacing.x1,
              ),
              foregroundDecoration: _focused
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(StreamRadii.sm),
                      border: Border.all(color: scheme.primary, width: 2),
                    )
                  : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(StreamRadii.sm),
                color: _hovered
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
                    : null,
              ),
              child: _LabelRow(
                dateLabel: widget.dateLabel,
                levelLabel: widget.levelLabel,
                slippedCount: widget.slippedCount,
                slippedSemanticLabel: widget.slippedSemanticLabel,
                fg: fg,
                scheme: scheme,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({
    required this.dateLabel,
    required this.levelLabel,
    required this.slippedCount,
    required this.slippedSemanticLabel,
    required this.fg,
    required this.scheme,
  });

  final String dateLabel;
  final String levelLabel;
  final int? slippedCount;
  final String? slippedSemanticLabel;
  final Color fg;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            dateLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: StreamTypeScale.sm,
              fontWeight: FontWeight(StreamFontWeight.medium),
              color: fg,
            ),
          ),
        ),
        const SizedBox(width: StreamSpacing.x1),
        Flexible(
          child: Text(
            levelLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: StreamTypeScale.xs,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (slippedCount != null) ...[
          const SizedBox(width: StreamSpacing.x1),
          _SlippedBadge(
            count: slippedCount!,
            semanticLabel: slippedSemanticLabel,
            scheme: scheme,
          ),
        ],
      ],
    );
  }
}

class _SlippedBadge extends StatelessWidget {
  const _SlippedBadge({
    required this.count,
    required this.semanticLabel,
    required this.scheme,
  });

  final int count;
  final String? semanticLabel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StreamSpacing.x1,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(StreamRadii.full),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: StreamTypeScale.xs,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: scheme.onTertiaryContainer,
          ),
        ),
      ),
    );
  }
}
