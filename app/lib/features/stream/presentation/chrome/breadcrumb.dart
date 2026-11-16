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
    if (widget.slippedCount != null && widget.slippedCount! > 0) {
      if (widget.slippedSemanticLabel != null) {
        return '$base, ${widget.slippedSemanticLabel} ${widget.slippedCount}';
      }
      return '$base, ${widget.slippedCount}';
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
      excludeSemantics: true,
      label: _semanticLabel,
      onTap: _disabled ? null : widget.onTap,
      child: _BreadcrumbTapArea(
        focusNode: _focusNode,
        disabled: _disabled,
        hovered: _hovered,
        focused: _focused,
        scheme: scheme,
        fg: fg,
        dateLabel: widget.dateLabel,
        levelLabel: widget.levelLabel,
        slippedCount: widget.slippedCount,
        onHoverChanged: (v) {
          if (!_disabled && _hovered != v) setState(() => _hovered = v);
        },
        onTap: widget.onTap,
      ),
    );
  }
}

class _BreadcrumbTapArea extends StatelessWidget {
  const _BreadcrumbTapArea({
    required this.focusNode,
    required this.disabled,
    required this.hovered,
    required this.focused,
    required this.scheme,
    required this.fg,
    required this.dateLabel,
    required this.levelLabel,
    required this.slippedCount,
    required this.onHoverChanged,
    required this.onTap,
  });

  final FocusNode focusNode;
  final bool disabled;
  final bool hovered;
  final bool focused;
  final ColorScheme scheme;
  final Color fg;
  final String dateLabel;
  final String levelLabel;
  final int? slippedCount;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: InkWell(
          focusNode: focusNode,
          onTap: onTap,
          borderRadius: BorderRadius.circular(StreamRadii.sm),
          focusColor: scheme.primary.withValues(alpha: 0.12),
          hoverColor: disabled ? null : scheme.primary.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: StreamSpacing.x2,
              vertical: StreamSpacing.x1,
            ),
            foregroundDecoration: focused
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(StreamRadii.sm),
                    border: Border.all(color: scheme.primary, width: 2),
                  )
                : null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(StreamRadii.sm),
              color: (!disabled && hovered)
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
                  : null,
            ),
            child: BreadcrumbLabelRow(
              dateLabel: dateLabel,
              levelLabel: levelLabel,
              slippedCount: slippedCount,
              fg: fg,
              scheme: scheme,
            ),
          ),
        ),
      ),
    );
  }
}
