part of '../tasks_screen.dart';

/// Custom-order task list. Reordering is optimistic and persisted locally;
/// tap, swipe and long-press actions stay on each row. A drag handle is used
/// because long-press already opens the task action sheet.
class _CustomTaskList extends ConsumerStatefulWidget {
  const _CustomTaskList({required this.tasks, required this.listsById});

  final List<Task> tasks;
  final Map<String, TaskList> listsById;

  @override
  ConsumerState<_CustomTaskList> createState() => _CustomTaskListState();
}

class _CustomTaskListState extends ConsumerState<_CustomTaskList> {
  late List<Task> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = [...widget.tasks];
  }

  @override
  void didUpdateWidget(covariant _CustomTaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.tasks, widget.tasks)) {
      _tasks = [...widget.tasks];
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _tasks.removeAt(oldIndex);
      _tasks.insert(newIndex, item);
    });
    _persist();
  }

  Future<void> _persist() async {
    try {
      await ref.read(taskRepositoryProvider).reorderTasks([
        for (final task in _tasks) task.id,
      ]);
    } catch (_) {
      if (mounted) {
        setState(() => _tasks = [...widget.tasks]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: DsSpace.x24),
        itemCount: _tasks.length,
        onReorderItem: _onReorder,
        proxyDecorator: (child, index, animation) => Material(
          elevation: 0,
          color: scheme.surfaceContainerHigh,
          child: child,
        ),
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return _TaskItem(
            key: ValueKey('task-${task.id}'),
            task: task,
            list: task.listId == null ? null : widget.listsById[task.listId],
            reorderIndex: index,
          );
        },
      ),
    );
  }
}
