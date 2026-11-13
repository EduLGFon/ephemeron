part of '../task_action_sheet.dart';

mixin _TaskActionSheetActions on _TaskActionSheetBase {
  bool _isFutureOccurrence(Task task) {
    String? effective;
    if (task.plannedStart != null && task.plannedStart!.isNotEmpty) {
      effective = task.plannedStart!.length >= 10
          ? task.plannedStart!.substring(0, 10)
          : task.plannedStart;
    } else if (task.plannedDate != null) {
      effective = task.plannedDate;
    } else {
      effective = task.dueDate;
    }
    if (effective == null) return false;
    return occurrenceDate.compareTo(effective) > 0;
  }

  Future<void> _runAndClose(
    BuildContext context, {
    required Future<void> Function() action,
    required String message,
    VoidCallback? onUndo,
    bool warning = false,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    navigator.pop();
    try {
      await action();
    } catch (_) {
      if (messenger != null && navigator.mounted) {
        showErrorSnackBar(navigator.context, 'Could not update task.');
      }
      return;
    }
    if (warning) {
      AppFeedback.warning();
    } else {
      AppFeedback.success();
    }
    if (messenger == null || !navigator.mounted) return;
    if (onUndo != null) {
      showUndoSnackBar(navigator.context, message, onUndo: onUndo);
    } else {
      showAppSnackBar(navigator.context, message);
    }
  }
}
