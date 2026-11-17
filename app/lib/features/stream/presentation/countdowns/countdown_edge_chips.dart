import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'countdown_landmark_item.dart';

/// Which stream edge the chips pin to.
enum CountdownEdge { top, bottom }

/// Small chips for countdowns that fall outside the viewport.
///
/// The input [items] must already be ordered by proximity to the viewport
/// (nearest first); this widget takes the first two entries.
class CountdownEdgeChips extends StatelessWidget {
  const CountdownEdgeChips({
    super.key,
    required this.items,
    required this.edge,
    this.labelBuilder,
    this.daysLabelBuilder,
    this.onTap,
    this.onShowAll,
    this.aggregateLabel,
  });

  final List<CountdownLandmarkItem> items;
  final CountdownEdge edge;
  final String Function(CountdownLandmarkItem item)? labelBuilder;
  final String Function(CountdownLandmarkItem item)? daysLabelBuilder;
  final void Function(String id)? onTap;
  final VoidCallback? onShowAll;
  final String? aggregateLabel;

  String _chipLabel(CountdownLandmarkItem item) {
    if (labelBuilder != null) return labelBuilder!(item);
    if (daysLabelBuilder != null) return daysLabelBuilder!(item);
    return item.title;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final visible = items.take(2).toList(growable: false);
    final extra = items.length - visible.length;
    final aggregate = aggregateLabel ?? (extra > 0 ? '+$extra' : '');
    return Semantics(
      container: true,
      excludeSemantics: true,
      child: Align(
        alignment: edge == CountdownEdge.top
            ? Alignment.topLeft
            : Alignment.bottomLeft,
        child: Wrap(
          verticalDirection: edge == CountdownEdge.top
              ? VerticalDirection.down
              : VerticalDirection.up,
          spacing: StreamSpacing.x2,
          runSpacing: StreamSpacing.x2,
          children: [
            for (final item in visible)
              _Chip(
                title: item.title,
                daysLabel: _chipLabel(item),
                onTap: onTap == null ? null : () => onTap!(item.id),
                scheme: scheme,
              ),
            if (extra > 0 && aggregate.isNotEmpty)
              _Chip(
                title: aggregate,
                daysLabel: aggregate,
                onTap: onShowAll,
                scheme: scheme,
                isAggregate: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.title,
    required this.daysLabel,
    required this.scheme,
    this.onTap,
    this.isAggregate = false,
  });

  final String title;
  final String daysLabel;
  final ColorScheme scheme;
  final VoidCallback? onTap;
  final bool isAggregate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: isAggregate ? daysLabel : '$title, $daysLabel',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: StreamSpacing.x3,
              vertical: StreamSpacing.x2,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(StreamRadii.full),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: StreamTypeScale.xs,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (!isAggregate) ...[
                  const SizedBox(width: StreamSpacing.x1),
                  Flexible(
                    child: Text(
                      daysLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: StreamTypeScale.xs,
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
