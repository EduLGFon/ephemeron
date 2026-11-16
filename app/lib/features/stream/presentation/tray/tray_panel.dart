import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'tray_item.dart';

class TrayGroup {
  TrayGroup({
    required this.listId,
    required this.listName,
    required this.colorArgb,
    List<TrayItem>? items,
  }) : items = items ?? <TrayItem>[];

  final String listId;
  final String listName;
  final int colorArgb;
  final List<TrayItem> items;
}

typedef TrayListGroup = TrayGroup;
typedef TrayPanelGroup = TrayGroup;

/// Expanded tray panel grouped by list. Fills the height given by the caller.
class TrayPanel extends StatelessWidget {
  const TrayPanel({
    super.key,
    this.groups,
    this.items,
    this.emptyLabel,
    this.emptyStateLabel,
    this.emptyText,
    this.collapseLabel,
    this.expandLabel,
    this.onCollapseRequested,
    this.onExpandRequested,
  });

  final List<TrayGroup>? groups;
  final List<TrayItem>? items;

  final String? emptyLabel;
  final String? emptyStateLabel;
  final String? emptyText;

  final String? collapseLabel;
  final String? expandLabel;

  final VoidCallback? onCollapseRequested;
  final VoidCallback? onExpandRequested;

  static const double itemExtent = 48;

  String get _emptyLabel => emptyLabel ?? emptyStateLabel ?? emptyText ?? '';

  List<TrayGroup> get _groups {
    if (groups != null) return groups!;
    final result = <TrayGroup>[];
    final index = <String, int>{};
    for (final item in items ?? const <TrayItem>[]) {
      if (!index.containsKey(item.listId)) {
        index[item.listId] = result.length;
        result.add(
          TrayGroup(
            listId: item.listId,
            listName: item.listName,
            colorArgb: item.colorArgb,
            items: <TrayItem>[],
          ),
        );
      }
      result[index[item.listId]!].items.add(item);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final list = _groups;
    if (list.isEmpty) {
      return Center(child: Text(_emptyLabel));
    }
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
            itemCount: list.length,
            itemBuilder: (context, gi) {
              final group = list[gi];
              final color = Color(group.colorArgb);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    label: '${group.listName}, ${group.items.length}',
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: StreamSpacing.x2,
                        vertical: StreamSpacing.x1,
                      ),
                      child: Row(
                        children: [
                          Container(width: 3, height: 16, color: color),
                          const SizedBox(width: StreamSpacing.x2),
                          Expanded(
                            child: Text(
                              group.listName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text('${group.items.length}'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: group.items.length * itemExtent,
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemExtent: itemExtent,
                      itemCount: group.items.length,
                      itemBuilder: (context, ii) {
                        final item = group.items[ii];
                        return Semantics(
                          container: true,
                          excludeSemantics: true,
                          label: '${item.title}, ${item.listName}',
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 20,
                                color: Color(item.colorArgb),
                              ),
                              const SizedBox(width: StreamSpacing.x2),
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
