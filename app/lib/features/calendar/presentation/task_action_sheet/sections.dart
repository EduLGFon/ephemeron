part of '../task_action_sheet.dart';

mixin _TaskActionSheetSections
    on _TaskActionSheetBase, _TaskActionSheetActions {
  Widget _buildHeader(
    BuildContext context,
    Task task, {
    required String sourceLabel,
    required String when,
    required bool isFuture,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$sourceLabel  •  $when',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (isFuture) ...[
            const SizedBox(height: 6),
            Text(
              'Future occurrence',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildStatusActions(
    BuildContext context,
    TaskRepository repo,
    Task task, {
    required bool isRecurring,
    required bool isProjectedOccurrence,
    required bool done,
    required bool wontDo,
    required int? previousCompletedAt,
  }) {
    if (isProjectedOccurrence) {
      return [
        StreamBuilder<TaskOccurrenceState?>(
          stream: repo.watchTaskOccurrenceState(task, occurrenceDate),
          builder: (context, stateSnap) {
            final state = stateSnap.data;
            if (state == null) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.check_rounded),
                    title: const Text('Mark as concluded'),
                    onTap: () => _runAndClose(
                      context,
                      action: () =>
                          repo.completeTaskOccurrence(task, occurrenceDate),
                      message: 'Occurrence completed',
                      onUndo: () =>
                          repo.uncompleteTaskOccurrence(task, occurrenceDate),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.block_rounded),
                    title: const Text("Won't do"),
                    onTap: () => _runAndClose(
                      context,
                      action: () =>
                          repo.markWontDoTaskOccurrence(task, occurrenceDate),
                      message: "Marked won't do",
                      warning: true,
                      onUndo: () =>
                          repo.uncompleteTaskOccurrence(task, occurrenceDate),
                    ),
                  ),
                ],
              );
            }
            final completedAt = state.completedAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    state.completedAt!,
                    isUtc: true,
                  );
            return ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: const Text('Mark as not concluded'),
              onTap: () => _runAndClose(
                context,
                action: () =>
                    repo.uncompleteTaskOccurrence(task, occurrenceDate),
                message: 'Occurrence reopened',
                onUndo: () {
                  if (state.status == 'wont_do') {
                    repo.markWontDoTaskOccurrence(
                      task,
                      occurrenceDate,
                      at: completedAt,
                    );
                  } else {
                    repo.completeTaskOccurrence(
                      task,
                      occurrenceDate,
                      at: completedAt,
                    );
                  }
                },
              ),
            );
          },
        ),
      ];
    }
    return [
      ListTile(
        leading: Icon(done ? Icons.undo_rounded : Icons.check_rounded),
        title: Text(done ? 'Mark as not concluded' : 'Mark as concluded'),
        onTap: () => _runAndClose(
          context,
          action: () =>
              done ? repo.uncompleteTask(taskId) : repo.completeTask(taskId),
          message: done ? 'Task reopened' : 'Completed "${task.title}"',
          onUndo: done
              ? () => repo.completeTask(taskId)
              : () => repo.uncompleteTask(taskId),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.block_rounded),
        title: const Text("Won't do"),
        enabled: !wontDo,
        onTap: wontDo
            ? null
            : () => _runAndClose(
                context,
                action: () => repo.markWontDo(taskId),
                message: "Marked won't do",
                warning: true,
                onUndo: () async {
                  await repo.updateTask(taskId, wontDo: false);
                  if (previousCompletedAt != null) {
                    await repo.completeTask(
                      taskId,
                      at: DateTime.fromMillisecondsSinceEpoch(
                        previousCompletedAt,
                        isUtc: true,
                      ),
                    );
                  } else {
                    await repo.uncompleteTask(taskId);
                  }
                },
              ),
      ),
      if (isRecurring)
        ListTile(
          leading: const Icon(Icons.skip_next),
          title: const Text('Skip occurrence'),
          onTap: () => _runAndClose(
            context,
            action: () => repo.skipOccurrence(taskId),
            message: 'Skipped occurrence',
          ),
        ),
    ];
  }

  Widget _buildSubtasks(
    BuildContext context,
    TaskRepository repo, {
    required bool isMs,
    required TaskList? list,
  }) {
    return StreamBuilder<List<Task>>(
      stream: repo.watchSubtasks(taskId),
      builder: (context, subSnap) {
        final subs = subSnap.data ?? const <Task>[];
        if (subs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('No subtasks'),
          );
        }
        return Column(
          children: [
            for (final s in subs)
              Builder(
                builder: (context) {
                  final subMs = isMicrosoftTask(
                    taskMicrosoftAccount: s.microsoftAccount,
                    listMicrosoftAccount: list?.microsoftAccount,
                  );
                  final readOnly = isMs || subMs;
                  return ListTile(
                    leading: IconButton(
                      icon: Icon(
                        s.completedAt != null
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                      ),
                      onPressed: readOnly
                          ? null
                          : () async {
                              final completing = s.completedAt == null;
                              AppFeedback.success();
                              await (completing
                                  ? repo.completeTask(s.id)
                                  : repo.uncompleteTask(s.id));
                              if (!context.mounted) return;
                              showUndoSnackBar(
                                context,
                                completing
                                    ? 'Subtask completed'
                                    : 'Subtask reopened',
                                onUndo: () {
                                  if (completing) {
                                    repo.uncompleteTask(s.id);
                                  } else {
                                    repo.completeTask(s.id);
                                  }
                                },
                              );
                            },
                    ),
                    title: Text(s.title),
                    onTap: readOnly
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            showTaskEditor(context, task: s);
                          },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
