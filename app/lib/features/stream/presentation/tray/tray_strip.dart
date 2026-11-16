import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'tray_chip.dart';
import 'tray_item.dart';

/// Horizontal strip of unscheduled task chips with a count badge and a
/// visible drag handle that requests expansion.
class TrayStrip extends StatelessWidget {
  const TrayStrip({
    super.key,
    required this.items,
    required this.onExpandRequested,
    this.countSemanticsLabel,
    this.countSemanticLabel,
    this.countBadgeSemanticsLabel,
    this.countLabel,
    this.emptyLabel,
    this.emptyStateLabel,
    this.emptyText,
    this.onTap,
    this.onItemTap,
    this.onTapItem,
    this.onChipTap,
  });

  final List<TrayItem> items;
  final VoidCallback onExpandRequested;

  final String? countSemanticsLabel;
  final String? countSemanticLabel;
  final String? countBadgeSemanticsLabel;
  final String? countLabel;

  final String? emptyLabel;
  final String? emptyStateLabel;
  final String? emptyText;

  final void Function(String id)? onTap;
  final void Function(String id)? onItemTap;
  final void Function(String id)? onTapItem;
  final void Function(String id)? onChipTap;

  String get _countLabel =>
      countSemanticsLabel ??
      countSemanticLabel ??
      countBadgeSemanticsLabel ??
      countLabel ??
      '${items.length}';

  String get _emptyLabel => emptyLabel ?? emptyStateLabel ?? emptyText ?? '';

  void Function(String id)? get _tap =>
      onTap ?? onItemTap ?? onTapItem ?? onChipTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Semantics(
        label: _emptyLabel,
        child: Center(child: Text(_emptyLabel)),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onExpandRequested,
          child: Container(
            height: 12,
            width: 48,
            margin: const EdgeInsets.only(bottom: StreamSpacing.x1),
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(StreamRadii.full),
            ),
          ),
        ),
        Row(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: StreamSpacing.x2,
              ),
              child: Semantics(
                excludeSemantics: true,
                label: _countLabel,
                child: Chip(
                  label: Text('${items.length}'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: StreamSpacing.x2),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemExtent: 120,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return SizedBox(
                      width: 120,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: StreamSpacing.x1,
                        ),
                        child: TrayChip(
                          key: ValueKey(item.id),
                          item: item,
                          onTap: () => _tap?.call(item.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
