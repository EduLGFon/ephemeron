import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'tray_chip.dart';
import 'tray_item.dart';

class TrayStrip extends StatelessWidget {
  const TrayStrip({
    super.key,
    required this.items,
    required this.countSemanticsLabel,
    required this.handleSemanticsLabel,
    required this.emptyLabel,
    required this.onExpandRequested,
    this.onTap,
  });

  final List<TrayItem> items;
  final String countSemanticsLabel;
  final String handleSemanticsLabel;
  final String emptyLabel;
  final VoidCallback onExpandRequested;
  final void Function(String id)? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: handleSemanticsLabel,
          child: Semantics(
            button: true,
            label: handleSemanticsLabel,
            onTap: onExpandRequested,
            child: GestureDetector(
              onTap: onExpandRequested,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Center(
                  child: Container(
                    height: 12,
                    width: 48,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(StreamRadii.full),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(StreamSpacing.x2),
            child: Text(emptyLabel),
          )
        else
          Row(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: StreamSpacing.x2,
                ),
                child: Semantics(
                  excludeSemantics: true,
                  label: countSemanticsLabel,
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
                      return Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: StreamSpacing.x1,
                        ),
                        child: TrayChip(
                          key: ValueKey(item.id),
                          item: item,
                          onTap: () => onTap?.call(item.id),
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
