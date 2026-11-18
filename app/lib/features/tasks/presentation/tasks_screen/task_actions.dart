part of '../tasks_screen.dart';

mixin _TaskRowActions on ConsumerWidget {
  Task get task;

  Future<void> _toggleComplete(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(taskRepositoryProvider);
    final strings = TasksStrings.of(context);
    final wasComplete = task.completedAt != null;
    try {
      if (wasComplete) {
        await repo.uncompleteTask(task.id);
      } else {
        await repo.completeTask(task.id);
      }
    } catch (_) {
      if (context.mounted) {
        showErrorSnackBar(context, strings.couldNotUpdateTask);
      }
      return;
    }
    AppFeedback.success();
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      wasComplete
          ? strings.taskReopened(task.title)
          : strings.taskCompleted(task.title),
      onUndo: wasComplete
          ? () => repo.completeTask(task.id)
          : () => repo.uncompleteTask(task.id),
    );
  }

  Future<void> _showActionSheet(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepositoryProvider);
    return showTaskActionSheet(
      context,
      taskId: task.id,
      occurrenceDate: repo.currentTaskOccurrenceKey(task),
    );
  }

  Future<void> _showRowActions(BuildContext context, WidgetRef ref) async {
    final strings = TasksStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final action = await showAppSheet<_TaskRowAction>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(title: task.title, subtitle: strings.rescheduleOrMore),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.x16),
            child: SectionTitle(title: strings.reschedule),
          ),
          ListTile(
            leading: const Icon(Icons.today_outlined),
            title: Text(strings.rescheduleToday),
            onTap: () =>
                Navigator.of(sheetContext).pop(_TaskRowAction.rescheduleToday),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(strings.rescheduleTomorrow),
            onTap: () =>
                Navigator.of(sheetContext)
                    .pop(_TaskRowAction.rescheduleTomorrow),
          ),
          ListTile(
            leading: const Icon(Icons.date_range_outlined),
            title: Text(strings.rescheduleNextWeek),
            onTap: () =>
                Navigator.of(sheetContext)
                    .pop(_TaskRowAction.rescheduleNextWeek),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outlined),
            title: Text(strings.moveToList),
            onTap: () =>
                Navigator.of(sheetContext).pop(_TaskRowAction.moveToList),
          ),
          ListTile(
            leading: const Icon(Icons.more_horiz),
            title: Text(strings.taskActions),
            onTap: () => Navigator.of(sheetContext).pop(_TaskRowAction.more),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: scheme.error),
            title: Text(strings.deleteTask),
            textColor: scheme.error,
            onTap: () => Navigator.of(sheetContext).pop(_TaskRowAction.delete),
          ),
          const SizedBox(height: DsSpace.x8),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _TaskRowAction.rescheduleToday:
        await _reschedule(context, ref, days: 0);
      case _TaskRowAction.rescheduleTomorrow:
        await _reschedule(context, ref, days: 1);
      case _TaskRowAction.rescheduleNextWeek:
        await _reschedule(context, ref, days: 7);
      case _TaskRowAction.moveToList:
        await pickAndMoveTask(
          context,
          ref,
          taskId: task.id,
          currentListId: task.listId,
        );
      case _TaskRowAction.more:
        await _showActionSheet(context, ref);
      case _TaskRowAction.delete:
        await _deleteTask(context, ref);
    }
  }

  Future<void> _reschedule(
    BuildContext context,
    WidgetRef ref, {
    required int days,
  }) async {
    final strings = TasksStrings.of(context);
    final repo = ref.read(taskRepositoryProvider);
    final target = DateTime.now().add(Duration(days: days));
    final key = dateKey(target);
    final dateLabel = DeviceDateFormat.shortDate(context, target);
    try {
      final startIso = task.plannedStart;
      if (startIso != null && startIso.length >= 10) {
        final previousEnd = task.plannedEnd;
        final startDate = _dateOnly(startIso);
        final endDate = _dateOnly(previousEnd);
        final span = startDate == null || endDate == null
            ? 0
            : endDate.difference(startDate).inDays;
        final newStart = _shiftIsoDate(startIso, target);
        final newEnd = previousEnd == null
            ? null
            : _shiftIsoDate(previousEnd, target.add(Duration(days: span)));
        await repo.updateTask(
          task.id,
          plannedStart: () => newStart,
          plannedEnd: () => newEnd,
        );
        if (!context.mounted) return;
        _afterReschedule(
          context,
          strings,
          dateLabel,
          () => repo.updateTask(
            task.id,
            plannedStart: () => startIso,
            plannedEnd: () => previousEnd,
          ),
        );
        return;
      }
      final planned = task.plannedDate;
      if (planned != null) {
        await repo.updateTask(task.id, plannedDate: () => key);
        if (!context.mounted) return;
        _afterReschedule(
          context,
          strings,
          dateLabel,
          () => repo.updateTask(task.id, plannedDate: () => planned),
        );
        return;
      }
      final previousDue = task.dueDate;
      await repo.updateTask(task.id, dueDate: () => key);
      if (!context.mounted) return;
      _afterReschedule(
        context,
        strings,
        dateLabel,
        () => repo.updateTask(task.id, dueDate: () => previousDue),
      );
    } catch (_) {
      if (!context.mounted) return;
      showErrorSnackBar(context, strings.couldNotUpdateTask);
    }
  }

  void _afterReschedule(
    BuildContext context,
    TasksStrings strings,
    String dateLabel,
    VoidCallback onUndo,
  ) {
    AppFeedback.success();
    showUndoSnackBar(
      context,
      strings.taskRescheduled(task.title, dateLabel),
      onUndo: onUndo,
    );
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref) async {
    final pending = ref.read(pendingOperationsProvider);
    final strings = TasksStrings.of(context);
    final opId = await pending.scheduleTaskDelete(task.id);
    AppFeedback.warning();
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      strings.taskDeleted(task.title),
      onUndo: () => pending.cancel(opId),
    );
  }
}

String _shiftIsoDate(String iso, DateTime date) =>
    '${dateKey(date)}${iso.length > 10 ? iso.substring(10) : ''}';

DateTime? _dateOnly(String? iso) {
  if (iso == null || iso.length < 10) return null;
  return DateTime.tryParse(iso.substring(0, 10));
}
