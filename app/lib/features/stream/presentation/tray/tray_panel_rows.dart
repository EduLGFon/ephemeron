import 'tray_item.dart';

abstract class TrayPanelRow {
  const TrayPanelRow();
  static const double extent = 48;
}

class TrayPanelHeaderRow extends TrayPanelRow {
  const TrayPanelHeaderRow({
    required this.listId,
    required this.listName,
    required this.colorArgb,
    required this.count,
  });

  final String listId;
  final String listName;
  final int colorArgb;
  final int count;
}

class TrayPanelItemRow extends TrayPanelRow {
  const TrayPanelItemRow(this.item, {required this.listName});

  final TrayItem item;
  final String listName;
}

List<TrayPanelRow> buildTrayPanelRows(
  List<TrayItem> items,
  String unnamedLabel,
) {
  final groups = <String, List<TrayItem>>{};
  final meta = <String, TrayItem>{};
  final seenIds = <String>{};
  for (final item in items) {
    if (!seenIds.add(item.id)) continue;
    groups.putIfAbsent(item.listId, () => <TrayItem>[]);
    groups[item.listId]!.add(item);
    meta.putIfAbsent(item.listId, () => item);
  }
  final rows = <TrayPanelRow>[];
  for (final entry in groups.entries) {
    final m = meta[entry.key]!;
    final named = entry.value.firstWhere(
      (i) => i.listName.isNotEmpty,
      orElse: () => entry.value.first,
    );
    final name = named.listName.isEmpty ? unnamedLabel : named.listName;
    rows.add(
      TrayPanelHeaderRow(
        listId: entry.key,
        listName: name,
        colorArgb: m.colorArgb,
        count: entry.value.length,
      ),
    );
    for (final item in entry.value) {
      rows.add(TrayPanelItemRow(item, listName: name));
    }
  }
  return rows;
}
