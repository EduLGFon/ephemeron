import 'package:material_ui/material_ui.dart';

import 'peek_data.dart';

/// List selector for the Peek editor.
class PeekListSelector extends StatelessWidget {
  const PeekListSelector({
    super.key,
    this.label,
    this.options,
    required this.listId,
    required this.listName,
    this.onPickList,
    required this.onChanged,
  });

  final String? label;
  final List<PeekListOption>? options;
  final String? listId;
  final String? listName;
  final Future<String?> Function(BuildContext context)? onPickList;
  final void Function(String? id, String? name) onChanged;

  @override
  Widget build(BuildContext context) {
    if (options != null && options!.isNotEmpty) {
      return DropdownButtonFormField<String?>(
        initialValue: listId,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: SizedBox.shrink(),
          ),
          for (final o in options!)
            DropdownMenuItem<String?>(
              value: o.id,
              child: Text(o.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          final name = v == null
              ? null
              : options!.firstWhere((o) => o.id == v).name;
          onChanged(v, name);
        },
      );
    }
    return InkWell(
      onTap: onPickList == null
          ? null
          : () async {
              final v = await onPickList!(context);
              final name = v == null
                  ? null
                  : (options
                            ?.firstWhere(
                              (o) => o.id == v,
                              orElse: () =>
                                  PeekListOption(id: v, name: listName ?? ''),
                            )
                            .name ??
                        listName);
              onChanged(v, v == null ? null : (name ?? listName));
            },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(listName ?? '', overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
