import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'breadcrumb_label_row.dart';

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

  String get _semanticLabel {
    final base = '${widget.dateLabel}, ${widget.levelLabel}';
    if (widget.slippedCount != null &&
        widget.slippedCount! > 0 &&
        widget.slippedSemanticLabel != null) {
      return '$base, ${widget.slippedSemanticLabel} ${widget.slippedCount}';
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
  }

  @override
  void dispose() {
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
      label: _semanticLabel,
      onTap: _disabled ? null : widget.onTap,
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
            hoverColor: _disabled
                ? null
                : scheme.primary.withValues(alpha: 0.06),
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
                color: (!_disabled && _hovered)
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
                    : null,
              ),
              child: BreadcrumbLabelRow(
                dateLabel: widget.dateLabel,
                levelLabel: widget.levelLabel,
                slippedCount: widget.slippedCount,
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
