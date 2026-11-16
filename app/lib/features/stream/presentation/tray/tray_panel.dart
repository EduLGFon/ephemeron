import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'tray_item.dart';
import 'tray_panel_header.dart';
import 'tray_panel_item.dart';
import 'tray_panel_rows.dart';

class TrayPanel extends StatefulWidget {
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
  State<TrayPanel> createState() => _TrayPanelState();
}

class _TrayPanelState extends State<TrayPanel> {
  List<TrayPanelRow> _rows = const <TrayPanelRow>[];

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(covariant TrayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _rebuild();
    }
  }

  void _rebuild() {
    _rows = buildTrayPanelRows(widget.items, widget.unnamedGroupLabel);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(child: Text(widget.emptyLabel));
    }
    return Column(
      children: [
        if (widget.collapseLabel != null)
          GestureDetector(
            onTap: widget.onCollapseRequested,
            child: Semantics(
              button: true,
              label: widget.collapseLabel,
              onTap: widget.onCollapseRequested,
              child: Padding(
                padding: const EdgeInsets.all(StreamSpacing.x2),
                child: Text(widget.collapseLabel!),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemExtent: TrayPanelRow.extent,
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final row = _rows[index];
              if (row is TrayPanelHeaderRow) {
                return TrayPanelHeader(
                  key: ValueKey('header:${row.listId}'),
                  row: row,
                );
              }
              final itemRow = row as TrayPanelItemRow;
              return TrayPanelItem(
                key: ValueKey(itemRow.item.id),
                item: itemRow.item,
                onTap: widget.onItemTap == null
                    ? null
                    : () => widget.onItemTap!(itemRow.item.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
