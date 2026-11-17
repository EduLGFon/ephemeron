import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'countdown_landmark_item.dart';

enum CountdownEdge { top, bottom }

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
    this.moreLabel,
    this.overflowLabel,
  });

  final List<CountdownLandmarkItem> items;
  final CountdownEdge edge;
  final String Function(CountdownLandmarkItem item)? labelBuilder;
  final String Function(CountdownLandmarkItem item)? daysLabelBuilder;
  final void Function(String id)? onTap;
  final VoidCallback? onShowAll;
  final String? aggregateLabel;
  final String? moreLabel;
  final String? overflowLabel;

  String _chipLabel(CountdownLandmarkItem item) {
    if (labelBuilder != null) return labelBuilder!(item);
    if (daysLabelBuilder != null) return daysLabelBuilder!(item);
    return item.title;
  }

  String get _aggregate => aggregateLabel ?? moreLabel ?? overflowLabel ?? '';

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final visible = items.take(2).toList(growable: false);
    final extra = items.length - visible.length;
    return Semantics(
      container: true,
      child: Wrap(
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
          if (extra > 0 && _aggregate.isNotEmpty)
            _Chip(
              title: _aggregate,
              daysLabel: _aggregate,
              onTap: onShowAll,
              scheme: scheme,
              isAggregate: true,
            ),
        ],
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
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
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
