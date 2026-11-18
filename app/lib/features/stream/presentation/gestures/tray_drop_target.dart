// Drop target for Tray chips dragged onto the Stream.
//
// Accepts a String id payload (Draggable data contract). Tray chips only start
// this drag after a long press and anchor it to the pointer, so a normal canvas
// pan or pinch never starts a drag and the drop time follows the finger; place
// this wrapper around the stream canvas without adding pan recognizers.

import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';

class TrayDropTarget extends StatefulWidget {
  const TrayDropTarget({
    super.key,
    required this.viewport,
    required this.child,
    required this.onTrayDrop,
    this.edgeMarginDp = 24,
  });

  final StreamTimeViewport viewport;
  final Widget child;
  final void Function(String id, int dropTimeMs) onTrayDrop;
  final int edgeMarginDp;

  @override
  State<TrayDropTarget> createState() => _TrayDropTargetState();
}

class _TrayDropTargetState extends State<TrayDropTarget> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      key: _key,
      onAcceptWithDetails: (details) {
        final box = _key.currentContext?.findRenderObject();
        if (box is! RenderBox) return;
        final local = box.globalToLocal(details.offset);
        if (local.dx < widget.edgeMarginDp ||
            local.dx > box.size.width - widget.edgeMarginDp) {
          return;
        }
        if (local.dy < 0 || local.dy > box.size.height) return;
        final time = widget.viewport.pxToTime(local.dy);
        widget.onTrayDrop(details.data, time);
      },
      builder: (context, candidate, rejected) => widget.child,
    );
  }
}
