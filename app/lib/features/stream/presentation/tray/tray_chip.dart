import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'tray_item.dart';

/// Compact chip for an unscheduled task. The caller wraps this in its own
/// draggable (e.g. LongPressDraggable); this widget only exposes [onDragStarted]
/// as a visual affordance hook and never schedules anything itself.
class TrayChip extends StatefulWidget {
  const TrayChip({
    super.key,
    required this.item,
    required this.onTap,
    this.onDragStarted,
  });

  final TrayItem item;
  final VoidCallback onTap;
  final VoidCallback? onDragStarted;

  @override
  State<TrayChip> createState() => _TrayChipState();
}

class _TrayChipState extends State<TrayChip> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(widget.item.colorArgb);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${widget.item.title}, ${widget.item.listName}',
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: AnimatedContainer(
              duration: StreamMotion.fast,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: StreamSpacing.x2,
                vertical: StreamSpacing.x1,
              ),
              decoration: BoxDecoration(
                color: _pressed
                    ? scheme.surfaceContainerHighest
                    : (_hovered
                          ? scheme.surfaceContainerHigh
                          : scheme.surfaceContainer),
                borderRadius: BorderRadius.circular(StreamRadii.sm),
                border: Border.all(color: scheme.outlineVariant, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 3, height: 20, color: color),
                  const SizedBox(width: StreamSpacing.x2),
                  Flexible(
                    child: Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: StreamTypeScale.sm),
                    ),
                  ),
                  if (widget.onDragStarted != null) ...[
                    const SizedBox(width: StreamSpacing.x1),
                    Icon(Icons.drag_indicator, size: StreamIconSize.sm),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
