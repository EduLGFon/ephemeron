import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'tray_item.dart';

/// Compact chip for an unscheduled task.
///
/// Long-press starts a [LongPressDraggable] carrying the task id, so a normal
/// tap still opens the editor and a quick horizontal swipe scrolls the tray
/// instead of starting a drag. Pointer anchoring keeps the drop time at the
/// finger once [TrayDropTarget] maps the drop point through its viewport.
///
/// This widget never schedules anything; [onDragStarted] is only a state hook
/// for callers that want to react to a drag starting.
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

  Widget _body({required bool pressed, required bool hovered}) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(widget.item.colorArgb);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: AnimatedContainer(
        duration: StreamMotion.fast,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: StreamSpacing.x2,
          vertical: StreamSpacing.x1,
        ),
        decoration: BoxDecoration(
          color: pressed
              ? scheme.surfaceContainerHighest
              : (hovered
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
            const SizedBox(width: StreamSpacing.x1),
            const Icon(Icons.drag_indicator, size: StreamIconSize.sm),
          ],
        ),
      ),
    );
  }

  Widget _tappableChip() {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: _body(pressed: _pressed, hovered: _hovered),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${widget.item.title}, ${widget.item.listName}',
      onTap: widget.onTap,
      child: LongPressDraggable<String>(
        data: widget.item.id,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: widget.onDragStarted,
        feedback: Material(
          type: MaterialType.transparency,
          child: _body(pressed: true, hovered: false),
        ),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: _body(pressed: false, hovered: false),
        ),
        child: _tappableChip(),
      ),
    );
  }
}
