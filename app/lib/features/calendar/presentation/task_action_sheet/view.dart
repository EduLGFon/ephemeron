part of '../task_action_sheet.dart';

mixin _TaskActionSheetView
    on _TaskActionSheetBase, _TaskActionSheetActions, _TaskActionSheetSections {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final repo = ref.watch(taskRepositoryProvider);
    final lists = ref
        .watch(taskListsProvider)
        .maybeWhen(data: (v) => v, orElse: () => const <TaskList>[]);

    final stream = (db.select(
      db.tasks,
    )..where((t) => t.id.equals(taskId))).watchSingleOrNull();

    return StreamBuilder<Task?>(
      stream: stream,
      builder: (context, snap) {
        final task = snap.data;
        if (task == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final isFuture = _isFutureOccurrence(task);
        final isRecurring = task.rrule != null && task.rrule!.isNotEmpty;
        final currentKey = repo.currentTaskOccurrenceKey(task);
        final isProjectedOccurrence =
            isRecurring && occurrenceDate != currentKey;
        TaskList? list;
        for (final l in lists) {
          if (l.id == task.listId) {
            list = l;
            break;
          }
        }
        final sourceLabel = list?.name ?? 'Tasks';
        final isMs = isMicrosoftTask(
          taskMicrosoftAccount: task.microsoftAccount,
          listMicrosoftAccount: list?.microsoftAccount,
        );

        DateTime? plannedDt;
        String? timeStr;
        if (task.plannedStart != null && task.plannedStart!.isNotEmpty) {
          plannedDt = DateTime.tryParse(task.plannedStart!);
          if (plannedDt != null) {
            timeStr = DeviceDateFormat.time(context, plannedDt);
            if (task.plannedEnd != null && task.plannedEnd!.isNotEmpty) {
              final endDt = DateTime.tryParse(task.plannedEnd!);
              if (endDt != null) {
                timeStr = '$timeStr - ${DeviceDateFormat.time(context, endDt)}';
              }
            }
          }
        } else if (task.plannedDate != null) {
          final p = task.plannedDate!.split('-');
          plannedDt = DateTime(
            int.parse(p[0]),
            int.parse(p[1]),
            int.parse(p[2]),
          );
          if (task.dueTime != null) {
            plannedDt = DateTime(
              plannedDt.year,
              plannedDt.month,
              plannedDt.day,
              task.dueTime! ~/ 60,
              task.dueTime! % 60,
            );
            timeStr = DeviceDateFormat.time(context, plannedDt);
          }
        } else if (task.dueDate != null) {
          final p = task.dueDate!.split('-');
          plannedDt = DateTime(
            int.parse(p[0]),
            int.parse(p[1]),
            int.parse(p[2]),
          );
          if (task.dueTime != null) {
            plannedDt = DateTime(
              plannedDt.year,
              plannedDt.month,
              plannedDt.day,
              task.dueTime! ~/ 60,
              task.dueTime! % 60,
            );
            timeStr = DeviceDateFormat.time(context, plannedDt);
          }
        }
        final dateStr = plannedDt == null
            ? occurrenceDate
            : DeviceDateFormat.date(context, plannedDt);
        final when = timeStr == null ? dateStr : '$dateStr - $timeStr';

        final done = task.completedAt != null;
        final wontDo = task.wontDo;
        final previousCompletedAt = task.completedAt;

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(
                context,
                task,
                sourceLabel: sourceLabel,
                when: when,
                isFuture: isFuture,
              ),
              const Divider(height: 1),
              if (!isMs)
                ..._buildStatusActions(
                  context,
                  repo,
                  task,
                  isRecurring: isRecurring,
                  isProjectedOccurrence: isProjectedOccurrence,
                  done: done,
                  wontDo: wontDo,
                  previousCompletedAt: previousCompletedAt,
                ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open tasks'),
                onTap: () {
                  final router = GoRouter.maybeOf(context);
                  Navigator.of(context).pop();
                  router?.go('/tab1');
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'Subtasks',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              _buildSubtasks(context, repo, isMs: isMs, list: list),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
