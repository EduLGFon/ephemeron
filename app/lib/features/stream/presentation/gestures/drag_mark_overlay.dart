// Overlay content rendered above the stream during a mark drag.
//
// The chip is positioned by the caller (via [offset]) so the stream below is
// not rebuilt on every pointer move. It never takes focus.

import 'package:material_ui/material_ui.dart';

/// Payload describing an in-flight drag preview.
///
/// [localPosition] is expressed relative to the gesture region that owns the
/// drag, so the overlay can be positioned with a [Positioned] inside the same
/// [Stack] without converting global coordinates.
class DragPreviewData {
  const DragPreviewData({
    required this.id,
    required this.localPosition,
    required this.label,
    this.timeLabel = '',
  });

  final String id;
  final Offset localPosition;
  final String label;
  final String timeLabel;
}

class DragMarkOverlay extends StatelessWidget {
  const DragMarkOverlay({
    super.key,
    required this.title,
    required this.timeLabel,
    this.offset,
    this.width,
  });

  final String title;
  final String timeLabel;
  final Offset? offset;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width ?? 220, minHeight: 32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                timeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );

    if (offset == null) return chip;
    return Positioned(left: offset!.dx, top: offset!.dy, child: chip);
  }
}
