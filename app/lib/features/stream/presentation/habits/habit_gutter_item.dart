/// Pure presentation model for a habit shown in the Stream gutter.
///
/// No Flutter imports: this is data injected by the caller.
class HabitGutterItem {
  const HabitGutterItem({
    required this.id,
    required this.name,
    required this.colorArgb,
    required this.doneByDay,
    this.timeMinutes,
    this.streakCurrent = 0,
    this.streakBest = 0,
  });

  final String id;
  final String name;
  final int colorArgb;

  /// Minutes from midnight; null means an all-day habit.
  final int? timeMinutes;

  /// Local day keys (yyyy-MM-dd) -> done state.
  final Map<String, bool> doneByDay;

  final int streakCurrent;
  final int streakBest;
}
