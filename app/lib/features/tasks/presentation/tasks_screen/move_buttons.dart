part of '../tasks_screen.dart';

enum _TaskTileAction { move, skip }

/// Single overflow menu for per-task actions. Keeps the tap target at 48 dp
/// and leaves swipe complete/delete and tap-to-edit intact.
class _TaskActionsMenu extends ConsumerWidget {
  const _TaskActionsMenu({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = task.listId == null
        ? null
        : ref.watch(taskListsByIdProvider)[task.listId];
    final isMs = isMicrosoftTask(
      taskMicrosoftAccount: task.microsoftAccount,
      listMicrosoftAccount: list?.microsoftAccount,
    );
    final canSkip = task.rrule != null && task.rrule!.isNotEmpty && !isMs;
    return Semantics(
      label: 'Task actions for ${task.title}',
      button: true,
      child: PopupMenuButton<_TaskTileAction>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Task actions',
        padding: const EdgeInsets.all(12),
        onSelected: (action) {
          switch (action) {
            case _TaskTileAction.move:
              _move(context, ref);
            case _TaskTileAction.skip:
              _skip(context, ref);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _TaskTileAction.move,
            enabled: !isMs,
            child: const Row(
              children: [
                Icon(Icons.drive_file_move_outlined),
                SizedBox(width: 12),
                Text('Move to list'),
              ],
            ),
          ),
          if (canSkip)
            const PopupMenuItem(
              value: _TaskTileAction.skip,
              child: Row(
                children: [
                  Icon(Icons.skip_next),
                  SizedBox(width: 12),
                  Text('Skip occurrence'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final lists = ref.read(taskListsProvider).value ?? const <TaskList>[];
    final current = task.listId;
    final target = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Move task to list'),
        children: [
          SimpleDialogOption(
            onPressed: current == null
                ? null
                : () => Navigator.of(ctx).pop('__none__'),
            child: _MoveOption(label: 'No list', selected: current == null),
          ),
          for (final l in lists)
            SimpleDialogOption(
              onPressed: l.id == current
                  ? null
                  : () => Navigator.of(ctx).pop(l.id),
              child: _MoveOption(label: l.name, selected: l.id == current),
            ),
        ],
      ),
    );
    if (target == null || !context.mounted) return;
    final repo = ref.read(taskRepositoryProvider);
    AppFeedback.success();
    final prev = await repo.moveTasks([
      task.id,
    ], target == '__none__' ? null : target);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      'Moved "${task.title}"',
      onUndo: () async {
        final r = ref.read(taskRepositoryProvider);
        for (final e in prev.entries) {
          await r.moveTasks([e.key], e.value);
        }
      },
    );
  }

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(taskRepositoryProvider);
    AppFeedback.tap();
    await repo.skipOccurrence(task.id);
    if (!context.mounted) return;
    showAppSnackBar(context, 'Skipped occurrence', icon: Icons.skip_next);
  }
}

class _MoveOption extends StatelessWidget {
  const _MoveOption({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: selected ? const Icon(Icons.check, size: 18) : null,
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
