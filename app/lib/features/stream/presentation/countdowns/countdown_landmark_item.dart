/// Pure immutable model for a countdown landmark on the Stream.
///
/// Presentation-layer data; no Flutter imports. A target is given either as
/// [targetDayKey] (a `yyyy-MM-dd` local calendar date) or [targetMs] (epoch
/// milliseconds in local time); at least one should be provided.
class CountdownLandmarkItem {
  const CountdownLandmarkItem({
    required this.id,
    required this.title,
    this.targetDayKey,
    this.targetMs,
    this.colorArgb,
  });

  final String id;
  final String title;
  final String? targetDayKey;
  final int? targetMs;
  final int? colorArgb;

  @override
  bool operator ==(Object other) =>
      other is CountdownLandmarkItem &&
      other.id == id &&
      other.title == title &&
      other.targetDayKey == targetDayKey &&
      other.targetMs == targetMs &&
      other.colorArgb == colorArgb;

  @override
  int get hashCode => Object.hash(id, title, targetDayKey, targetMs, colorArgb);
}
