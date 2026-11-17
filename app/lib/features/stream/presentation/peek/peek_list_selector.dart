import 'package:material_ui/material_ui.dart';

import 'peek_data.dart';

/// List selector for the Peek editor.
///
/// TaskRepository.updateTask treats a null list id as "leave unchanged", so a
/// cleared list cannot be saved. Offer only real lists: a null picker result
/// is treated as cancel, never as a clear that would silently do nothing.
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
          for (final o in options!)
            DropdownMenuItem<String?>(
              value: o.id,
              child: Text(o.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          final name = options!.firstWhere((o) => o.id == v).name;
          onChanged(v, name);
        },
      );
    }
    return InkWell(
      onTap: onPickList == null
          ? null
          : () async {
              final v = await onPickList!(context);
              if (v == null) return;
              final name =
                  options
                      ?.firstWhere(
                        (o) => o.id == v,
                        orElse: () =>
                            PeekListOption(id: v, name: listName ?? ''),
                      )
                      .name ??
                  listName;
              onChanged(v, name);
            },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(listName ?? '', overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
