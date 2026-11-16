part of '../event_details_sheet.dart';

/// Task detail content: title, due date, source, notes and actions.
class _TaskDetailsBody extends ConsumerWidget {
  const _TaskDetailsBody({
    required this.task,
    required this.source,
    required this.isMicrosoft,
  });

  final Task task;
  final String? source;
  final bool isMicrosoft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = task;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(
                t.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(
                t.dueDate == null
                    ? 'No due date'
                    : 'Due ${DeviceDateFormat.dateIso(context, t.dueDate!)}${t.dueTime == null ? '' : ' ${t.dueTime! ~/ 60}:${(t.dueTime! % 60).toString().padLeft(2, '0')}'}',
              ),
            ),
            _SourceTile(
              icon: Icons.list_alt_outlined,
              kind: 'List',
              label: source ?? 'No list',
              onTap: isMicrosoft
                  ? null
                  : () async {
                      final moved = await pickAndMoveTask(
                        context,
                        ref,
                        taskId: t.id,
                        currentListId: t.listId,
                      );
                      if (moved && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
            ),
            if (t.notes != null && t.notes!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.notes_outlined),
                title: Text(t.notes!),
              ),
            EntityCountdownSection(
              linkedType: 'task',
              linkedId: t.id,
              initialTitle: t.title,
              initialDate: parseCountdownDate(t.dueDate),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isMicrosoft
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              showTaskEditor(context, task: t);
                            },
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isMicrosoft
                          ? null
                          : () async {
                              final pending = ref.read(
                                pendingOperationsProvider,
                              );
                              final opId = await pending.scheduleTaskDelete(
                                t.id,
                              );
                              try {
                                ref
                                    .read(occurrenceDirtyProvider.notifier)
                                    .markDirty();
                              } catch (_) {}
                              if (!context.mounted) return;
                              AppFeedback.warning();
                              showUndoSnackBar(
                                context,
                                'Deleted "${t.title}"',
                                onUndo: () => pending.cancel(opId),
                              );
                              Navigator.of(context).pop();
                            },
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                onPressed: (t.completedAt == null && !isMicrosoft)
                    ? () async {
                        await ref
                            .read(taskRepositoryProvider)
                            .completeTask(t.id);
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    : null,
                icon: const Icon(Icons.check),
                label: Text(
                  t.completedAt == null ? 'Mark as done' : 'Completed',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
