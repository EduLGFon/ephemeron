/// Pure presentation model for an unscheduled task chip in the Stream tray.
class TrayItem {
  const TrayItem({
    required this.id,
    required this.title,
    required this.listId,
    required this.listName,
    required this.colorArgb,
  });

  final String id;
  final String title;
  final String listId;
  final String listName;
  final int colorArgb;

  @override
  bool operator ==(Object other) =>
      other is TrayItem &&
      other.id == id &&
      other.title == title &&
      other.listId == listId &&
      other.listName == listName &&
      other.colorArgb == colorArgb;

  @override
  int get hashCode => Object.hash(id, title, listId, listName, colorArgb);
}
