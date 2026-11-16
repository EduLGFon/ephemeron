import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'tray_item.dart';
import 'tray_panel_header.dart';
import 'tray_panel_item.dart';
import 'tray_panel_rows.dart';

class TrayPanel extends StatelessWidget {
  const TrayPanel({
    super.key,
    required this.items,
    required this.emptyLabel,
    this.unnamedGroupLabel = 'Unnamed',
    this.collapseLabel,
    this.onCollapseRequested,
    this.onItemTap,
  });

  final List<TrayItem> items;
  final String emptyLabel;
  final String unnamedGroupLabel;
  final String? collapseLabel;
  final VoidCallback? onCollapseRequested;
  final void Function(String id)? onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyLabel));
    }
    final rows = buildTrayPanelRows(items, unnamedGroupLabel);
    return Column(
      children: [
        if (collapseLabel != null)
          GestureDetector(
            onTap: onCollapseRequested,
            child: Semantics(
              button: true,
              label: collapseLabel,
              onTap: onCollapseRequested,
              child: Padding(
                padding: const EdgeInsets.all(StreamSpacing.x2),
                child: Text(collapseLabel!),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemExtent: TrayPanelRow.extent,
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row is TrayPanelHeaderRow) {
                return TrayPanelHeader(
                  key: ValueKey('h:${row.listId}'),
                  row: row,
                );
              }
              final itemRow = row as TrayPanelItemRow;
              return TrayPanelItem(
                key: ValueKey('i:${itemRow.item.id}'),
                item: itemRow.item,
                unnamedGroupLabel: unnamedGroupLabel,
                onTap: onItemTap == null
                    ? null
                    : () => onItemTap!(itemRow.item.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
