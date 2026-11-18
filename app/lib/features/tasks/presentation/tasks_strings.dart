// English copy for the Tasks screen. Each feature owns its strings so
// localization can grow without touching the shared ARB files.
import 'package:material_ui/material_ui.dart';

import '../../../domain/tasks/task_sort.dart';

class TasksStrings {
  const TasksStrings(this.locale);

  final Locale locale;

  static TasksStrings of(BuildContext context) =>
      TasksStrings(Localizations.localeOf(context));

  String get title => 'Tasks';
  String get search => 'Search tasks';
  String get searchHint => 'Search tasks';
  String get sortTasks => 'Sort tasks';
  String get moreActions => 'More actions';
  String get manageLists => 'Manage lists';
  String get manageSmartLists => 'Manage smart lists';
  String get trash => 'Trash';

  String get allLists => 'All';
  String get newList => 'New list';
  String get newSmartList => 'New smart list';
  String get syncedList => 'Synced list';

  String get filterAll => 'All';
  String get filterToday => 'Today';
  String get filterUpcoming => 'Upcoming';
  String get filterCompleted => 'Completed';

  String get overdue => 'Overdue';
  String get rescheduleAll => 'Reschedule overdue tasks to today';
  String get pinned => 'Pinned';
  String reorderTask(String title) => 'Reorder $title';

  String get emptyTitle => 'No tasks here';
  String get emptyMessage =>
      'Add a task with details like #tag, ~list, or tomorrow 9h.';
  String get addTask => 'Add a task';
  String get manageListsAction => 'Manage lists';
  String get noMatchesTitle => 'No tasks match';
  String noMatchesMessage(String name) => 'Nothing matches "$name" right now.';
  String get editSmartList => 'Edit smart list';
  String get searchEmptyTitle => 'No matches';
  String searchEmptyMessage(String query) => 'Nothing matches "$query".';
  String get closeSearch => 'Close search';
  String get todayEmptyTitle => 'Nothing due today';
  String get todayEmptyMessage =>
      'Tasks due or planned for today show up here.';
  String get upcomingEmptyTitle => 'Nothing upcoming';
  String get upcomingEmptyMessage => 'Tasks with a future date show up here.';
  String get completedEmptyTitle => 'Nothing completed yet';
  String get completedEmptyMessage => 'Completed tasks appear here.';

  String get errorTitle => 'Could not load tasks';
  String get errorMessage => 'Check your data and try again.';
  String get retry => 'Try again';

  String due(String date) => 'Due $date';
  String dueAt(String date, String time) => 'Due $date, $time';
  String planned(String date) => 'Planned $date';
  String plannedRange(String start, String end) => 'Planned $start - $end';

  String get rescheduleOrMore => 'Reschedule or more';
  String get reschedule => 'Reschedule';
  String get rescheduleToday => 'Today';
  String get rescheduleTomorrow => 'Tomorrow';
  String get rescheduleNextWeek => 'Next week';
  String get moveToList => 'Move to list';
  String get taskActions => 'More actions';
  String get deleteTask => 'Delete task';

  String taskCompleted(String title) => 'Completed "$title"';
  String taskReopened(String title) => 'Reopened "$title"';
  String taskDeleted(String title) => 'Deleted "$title"';
  String taskRescheduled(String title, String date) =>
      'Rescheduled "$title" to $date';
  String rescheduledCount(int count) =>
      count == 1 ? 'Rescheduled 1 task' : 'Rescheduled $count tasks';
  String get couldNotUpdateTask => 'Could not update task';

  String get editSmartListAction => 'Edit smart list';
  String get deleteSmartListAction => 'Delete smart list';

  String sortLabel(TaskSort sort) => switch (sort) {
    TaskSort.custom => 'Custom order',
    TaskSort.name => 'Name',
    TaskSort.created => 'Created',
    TaskSort.due => 'Due date',
  };
}
