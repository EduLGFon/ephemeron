/// Pure immutable model for a slipped (overdue, unfinished) task.
///
/// Presentation-layer data; no Flutter imports.
class SlippedItem {
  const SlippedItem({
    required this.id,
    required this.title,
    required this.daysOverdue,
    required this.listColorArgb,
  });

  final String id;
  final String title;
  final int daysOverdue;
  final int listColorArgb;

  @override
  bool operator ==(Object other) =>
      other is SlippedItem &&
      other.id == id &&
      other.title == title &&
      other.daysOverdue == daysOverdue &&
      other.listColorArgb == listColorArgb;

  @override
  int get hashCode => Object.hash(id, title, daysOverdue, listColorArgb);
}
