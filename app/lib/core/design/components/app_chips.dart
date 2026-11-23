// Selection chips. Selected state is carried by a check icon and selected
// semantics as well as the tonal fill, so status never depends on colour alone.
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import '../typography.dart';

// The wheel is the vertical counterpart to these chips. Re-exporting it here
// keeps single-import libraries (for example the quick-add sheet, whose parent
// already imports this file) able to use the shared selector.
export 'app_wheel.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.icon,
    this.color,
    this.dense = false,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final Color? color;
  final bool dense;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tappable = onTap != null || onLongPress != null;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outlineVariant,
      ),
    );
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? DsSpace.x8 : DsSpace.x12,
        vertical: DsSpace.x4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (selected) ...<Widget>[
            Icon(Icons.check, size: DsIcon.sm, color: foreground),
            const SizedBox(width: DsSpace.x4),
          ],
          if (color != null) ...<Widget>[
            _ColorDot(color: color!),
            const SizedBox(width: DsSpace.x8),
          ],
          if (icon != null) ...<Widget>[
            Icon(icon, size: DsIcon.sm, color: foreground),
            const SizedBox(width: DsSpace.x8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsType.numeric(
                (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
                  color: foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final body = Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
      shape: shape,
      clipBehavior: onTap == null && onLongPress == null
          ? Clip.none
          : Clip.antiAlias,
      child: tappable
          ? InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              customBorder: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(widthFactor: 1, heightFactor: 1, child: content),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(widthFactor: 1, heightFactor: 1, child: content),
            ),
    );

    final chip = Semantics(button: tappable, selected: selected, child: body);
    final message = tooltip;
    return message == null ? chip : Tooltip(message: message, child: chip);
  }
}

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
    this.count,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final text = count == null ? label : '$label ($count)';
    return AppChip(
      label: text,
      selected: selected,
      color: color,
      onTap: () => onSelected(!selected),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
