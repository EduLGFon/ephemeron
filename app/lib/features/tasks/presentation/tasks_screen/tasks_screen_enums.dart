part of '../tasks_screen.dart';

enum _TasksAction { manageLists, manageSmartLists, trash }

enum _SmartAction { edit, delete }

enum _TaskFilter { all, today, upcoming, completed }

enum _TaskRowAction {
  rescheduleToday,
  rescheduleTomorrow,
  rescheduleNextWeek,
  moveToList,
  more,
  delete,
}
