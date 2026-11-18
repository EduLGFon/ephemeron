part of '../tasks_screen.dart';

extension on TasksScreen {
  void _onAction(BuildContext context, WidgetRef ref, _TasksAction action) {
    switch (action) {
      case _TasksAction.manageLists:
        _openLists(context);
      case _TasksAction.manageSmartLists:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SmartListsScreen()),
        );
      case _TasksAction.trash:
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const TrashScreen()));
    }
  }

  void _openLists(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const TaskListsScreen()));
  }

  Future<void> _select(WidgetRef ref, String? id) async {
    ref.read(selectedTaskListProvider.notifier).select(id);
    ref.read(selectedSmartListProvider.notifier).select(null);
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.setSelectedTaskListId(id);
    } catch (_) {
      // Persistence is best effort: the in-memory selection stays valid.
    }
  }

  Future<void> _selectSmart(WidgetRef ref, String id) async {
    ref.read(selectedSmartListProvider.notifier).select(id);
    ref.read(selectedTaskListProvider.notifier).select(null);
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.setSelectedTaskListId(null);
    } catch (_) {
      // Persistence is best effort: the in-memory selection stays valid.
    }
  }

  Future<void> _smartActions(
    BuildContext context,
    WidgetRef ref,
    SmartList smart,
  ) async {
    final strings = TasksStrings.of(context);
    final action = await showAppSheet<_SmartAction>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHeader(title: smart.name, subtitle: strings.manageSmartLists),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(strings.editSmartListAction),
            onTap: () => Navigator.of(ctx).pop(_SmartAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(strings.deleteSmartListAction),
            onTap: () => Navigator.of(ctx).pop(_SmartAction.delete),
          ),
          const SizedBox(height: DsSpace.x8),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _SmartAction.edit) {
      await showSmartListEditor(context, smartList: smart);
      return;
    }
    await ref.read(taskRepositoryProvider).deleteSmartList(smart.id);
    if (ref.read(selectedSmartListProvider) == smart.id) {
      ref.read(selectedSmartListProvider.notifier).select(null);
    }
  }

  Future<void> _rescheduleAll(
    BuildContext context,
    WidgetRef ref,
    List<Task> overdue,
  ) async {
    final repo = ref.read(taskRepositoryProvider);
    final today = dateKey(DateTime.now());
    var count = 0;
    for (final task in overdue) {
      final list = task.listId == null
          ? null
          : ref.read(taskListsByIdProvider)[task.listId];
      if (isMicrosoftTask(
        taskMicrosoftAccount: task.microsoftAccount,
        listMicrosoftAccount: list?.microsoftAccount,
      )) {
        continue;
      }
      await repo.updateTask(task.id, dueDate: () => today);
      count++;
    }
    if (count == 0 || !context.mounted) return;
    showAppSnackBar(context, TasksStrings.of(context).rescheduledCount(count));
  }
}
