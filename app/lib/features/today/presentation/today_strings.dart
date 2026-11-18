// Typed English strings for the Today home. Kept per feature so a later
// localization unit can translate the screen without touching shared ARB
// files.
import 'package:material_ui/material_ui.dart';

class TodayStrings {
  const TodayStrings();

  static TodayStrings of(BuildContext context) {
    // English for now; the locale lookup keeps the call site future-proof.
    switch (Localizations.localeOf(context).languageCode) {
      default:
        return const TodayStrings();
    }
  }

  String get goodMorning => 'Good morning';
  String get goodAfternoon => 'Good afternoon';
  String get goodEvening => 'Good evening';

  String get today => 'Today';
  String get overdue => 'Overdue';
  String get allDay => 'All day';
  String get now => 'Now';
  String get next => 'Next';
  String get anytime => 'Anytime';
  String get noTime => 'No time';

  String get habitsTitle => 'Habits';
  String get countdownsTitle => 'Countdowns';
  String get seeAll => 'See all';
  String get addSomething => 'Add something';
  String get emptyTitle => 'A clear day';
  String get emptyMessage => 'Nothing scheduled. Make room for what matters.';
  String get clearHero => 'Nothing scheduled right now';

  String get settingsTooltip => 'Settings';
  String get moreTooltip => 'More';
  String get syncTooltip => 'Sync status';
  String get search => 'Search';
  String get retry => 'Retry';
  String get couldNotLoad => 'Could not load today.';
  String get taskCompleted => 'Task completed';
  String get couldNotComplete => 'Could not complete the task.';
  String get couldNotUpdateHabit => 'Could not update the habit.';

  String get focusPause => 'Pause';
  String get focusResume => 'Resume';
  String get focusStop => 'Stop';
  String get focusPaused => 'Focus paused';

  String endsIn(int minutes) => 'ends in ${_minutes(minutes)}';
  String inMinutes(int minutes) => 'in ${_minutes(minutes)}';
  String overdueCount(int count) => '$count overdue';
  String habitProgress(int percent) => '$percent% of goal';
  String countdownDays(int days) {
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    if (days > 1) return 'in $days days';
    if (days == -1) return 'yesterday';
    return '${-days} days ago';
  }

  String _minutes(int value) {
    if (value <= 1) return '1 min';
    if (value < 60) return '$value min';
    final hours = value ~/ 60;
    final minutes = value % 60;
    if (minutes == 0) return '$hours h';
    return '$hours h $minutes min';
  }
}
