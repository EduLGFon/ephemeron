// User-visible strings for the habits screens. English only for now; every
// string lives here so a future locale can override without touching widgets.
import 'package:material_ui/material_ui.dart';

class HabitsStrings {
  const HabitsStrings(this.locale);

  final Locale locale;

  static HabitsStrings of(BuildContext context) =>
      HabitsStrings(Localizations.localeOf(context));

  String get title => 'Habits';
  String get statisticsTooltip => 'Habit statistics';
  String get heatmapTooltip => 'Habit heatmap';
  String get showArchivedTooltip => 'Show archived';
  String get hideArchivedTooltip => 'Hide archived';
  String get addHabit => 'Add habit';
  String get emptyTitle => 'No habits yet.';
  String get emptyMessage =>
      'Small daily actions add up. Create your first one.';
  String get emptyArchivedTitle => 'No archived habits.';
  String get emptyArchivedMessage => 'Archived habits appear here.';
  String get loadError => 'Could not load habits.';
  String get retry => 'Retry';
  String get today => 'Today';
  String get noSection => 'Other';
  String get clearSelectionTooltip => 'Clear selection';

  String selected(int count) => '$count selected';
  String habitCount(int count) => count == 1 ? '1 habit' : '$count habits';
  String streak(int days) => days == 1 ? '1 day streak' : '$days day streak';
  String bestStreak(int days) => 'Best $days';

  String get skipDay => 'Skip day';
  String get unskipDay => 'Unskip day';
  String get skipped => 'Skipped';
  String get done => 'Done';
  String get startTimer => 'Start timer';
  String get stopTimer => 'Stop timer';
  String get timerOnlyToday => 'Timer can only start for today.';
  String get anotherTimerRunning => 'Another habit timer is already running.';
  String loggedMinutes(String amount) => 'Logged $amount';
  String get moreOptions => 'More options';
  String get editHabit => 'Edit habit';
  String get viewActivity => 'View activity';
  String addStep(String step) => 'Add $step';
  String subtractStep(String step) => 'Subtract $step';
  String get progressSemantics => 'Progress';

  String get archive => 'Archive';
  String get unarchive => 'Unarchive';
  String get delete => 'Delete';
  String archivedMessage(int count) =>
      count == 1 ? 'Habit archived.' : 'Habits archived.';
  String unarchivedMessage(int count) =>
      count == 1 ? 'Habit unarchived.' : 'Habits unarchived.';
  String deletedMessage(int count) =>
      count == 1 ? 'Habit deleted.' : 'Habits deleted.';
  String get undo => 'Undo';
  String deleteDialogTitle(int count) =>
      count == 1 ? 'Delete 1 habit?' : 'Delete $count habits?';
  String deleteDialogBody(int count) => count == 1
      ? 'This habit will be deleted.'
      : 'These $count habits will be deleted.';
  String get cancel => 'Cancel';

  String get heatmapTitle => 'Habit activity';
  String get heatmapSubtitle => 'Last 16 weeks, Monday first.';
  String get heatmapEmpty => 'No active habits to chart.';
  String heatmapSemantics(String name) => '$name activity, last 16 weeks';
  String weekSummary(int done, int active) => '$done of $active weeks active';
}
