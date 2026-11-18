// Flat action buttons. One wrapper keeps minimum touch targets, variants,
// busy state and focus treatment consistent across screens.
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.busy = false,
    this.tooltip,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool busy;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !busy;
    final foreground = switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.danger => scheme.onError,
      AppButtonVariant.secondary => scheme.onSurface,
      AppButtonVariant.ghost => scheme.primary,
    };

    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: DsIcon.sm),
          const SizedBox(width: DsSpace.x8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
    if (busy) {
      // Keep the idle content in the tree so the busy button does not resize.
      content = Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: content,
          ),
          SizedBox(
            width: DsIcon.sm,
            height: DsIcon.sm,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          ),
        ],
      );
    }

    final style = _style(context, foreground: foreground, busy: busy);
    Widget button = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.danger => FilledButton(
        style: style,
        onPressed: enabled ? onPressed : null,
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        style: style,
        onPressed: enabled ? onPressed : null,
        child: content,
      ),
      AppButtonVariant.ghost => TextButton(
        style: style,
        onPressed: enabled ? onPressed : null,
        child: content,
      ),
    };

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    final labelText = semanticLabel;
    if (labelText != null) {
      button = Semantics(
        container: true,
        button: true,
        enabled: enabled,
        label: labelText,
        onTap: enabled ? onPressed : null,
        child: ExcludeSemantics(child: button),
      );
    }
    return button;
  }

  ButtonStyle _style(
    BuildContext context, {
    required Color foreground,
    required bool busy,
  }) {
    final scheme = Theme.of(context).colorScheme;
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(DsRadius.r12)),
    );
    const padding = EdgeInsets.symmetric(
      horizontal: DsSpace.x16,
      vertical: DsSpace.x8,
    );
    final base = switch (variant) {
      AppButtonVariant.primary => FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        minimumSize: const Size(0, 48),
        padding: padding,
        shape: shape,
      ),
      AppButtonVariant.danger => FilledButton.styleFrom(
        backgroundColor: scheme.error,
        foregroundColor: scheme.onError,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        minimumSize: const Size(0, 48),
        padding: padding,
        shape: shape,
      ),
      AppButtonVariant.secondary => OutlinedButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        side: BorderSide(color: scheme.outline),
        minimumSize: const Size(0, 48),
        padding: padding,
        shape: shape,
      ),
      AppButtonVariant.ghost => TextButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        minimumSize: const Size(0, 48),
        padding: padding,
        shape: shape,
      ),
    };
    final normalSide = switch (variant) {
      AppButtonVariant.secondary => BorderSide(color: scheme.outline),
      AppButtonVariant.primary ||
      AppButtonVariant.ghost ||
      AppButtonVariant.danger => BorderSide.none,
    };
    final resolved = base.copyWith(
      side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: scheme.onSurface, width: 1.5);
        }
        return normalSide;
      }),
    );
    if (!busy) return resolved;
    // Busy blocks activation but keeps the enabled fill so the small progress
    // arc does not disappear into a disabled-looking button.
    final background = switch (variant) {
      AppButtonVariant.primary => scheme.primary,
      AppButtonVariant.danger => scheme.error,
      AppButtonVariant.secondary || AppButtonVariant.ghost => null,
    };
    return resolved.copyWith(
      backgroundColor: WidgetStatePropertyAll<Color?>(background),
      foregroundColor: WidgetStatePropertyAll<Color>(foreground),
      side: WidgetStatePropertyAll<BorderSide?>(normalSide),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
    this.size = DsIcon.md,
    this.semanticLabel,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;
  final double size;
  final String? semanticLabel;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    Widget button = IconButton(
      onPressed: onPressed,
      isSelected: selected,
      tooltip: semanticLabel == null ? tooltip : null,
      iconSize: size,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(Size(48, 48)),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.all(DsSpace.x12),
        ),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.secondaryContainer;
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          return selected
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant;
        }),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(DsRadius.r12)),
          ),
        ),
        side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: scheme.onSurface, width: 1.5);
          }
          return BorderSide.none;
        }),
      ),
      icon: Icon(icon),
    );

    if (tooltip != null && semanticLabel != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    if (badge != null) {
      button = Badge(label: Text(badge!), child: button);
    }
    final label = semanticLabel;
    if (label != null) {
      button = Semantics(
        container: true,
        button: true,
        enabled: enabled,
        selected: selected,
        label: label,
        onTap: enabled ? onPressed : null,
        child: ExcludeSemantics(child: button),
      );
    }
    return button;
  }
}
