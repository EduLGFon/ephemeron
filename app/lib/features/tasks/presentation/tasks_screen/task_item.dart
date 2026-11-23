part of '../tasks_screen.dart';

class _TaskItem extends ConsumerWidget with _TaskRowActions {
  const _TaskItem({
    super.key,
    required this.task,
    this.list,
    this.overdue = false,
    this.reorderIndex,
  });

  @override
  final Task task;
  final TaskList? list;
  final bool overdue;
  final int? reorderIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = TasksStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isMicrosoft = isMicrosoftTask(
      taskMicrosoftAccount: task.microsoftAccount,
      listMicrosoftAccount: list?.microsoftAccount,
    );
    final completed = task.completedAt != null;
    // The list groups overdue tasks, but other filters do not populate that
    // flag. Derive it from the deadline so the red date label stays correct
    // in every view.
    final due = _dueDateTime();
    final displayOverdue =
        !completed && due != null && dateKey(due).compareTo(_todayKey()) < 0;
    return Dismissible(
      key: ValueKey('task-dismiss-${task.id}'),
      direction: isMicrosoft
          ? DismissDirection.none
          : DismissDirection.horizontal,
      background: _SwipeBackground(
        color: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
        icon: Icons.check,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
        icon: Icons.schedule,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _toggleComplete(context, ref);
        } else {
          await _showRowActions(context, ref);
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _showActionSheet(context, ref),
        child: AppTaskRow(
          title: task.title,
          subtitle: _rowSubtitle(context, strings),
          listColor: list == null ? null : taskListColor(list!),
          priority: task.priority == 0 ? 0 : 5 - task.priority,
          completed: completed,
          overdue: overdue || displayOverdue,
          onTap: isMicrosoft ? null : () => showTaskEditor(context, task: task),
          onToggle: isMicrosoft ? null : () => _toggleComplete(context, ref),
          trailing: _trailing(strings, scheme),
        ),
      ),
    );
  }

  String? _rowSubtitle(BuildContext context, TasksStrings strings) {
    final when = _whenLabel(context, strings);
    final listName = list?.name;
    if (listName == null) return when;
    if (when == null) return listName;
    return '$listName - $when';
  }

  DateTime? _dueDateTime() {
    final raw = task.dueDate;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _todayKey() => dateKey(DateTime.now());

  String? _dueTimeLabel(BuildContext context) {
    final minutes = task.dueTime;
    if (minutes == null) return null;
    return DeviceDateFormat.time(
      context,
      DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60),
    );
  }

  String? _whenLabel(BuildContext context, TasksStrings strings) {
    final startIso = task.plannedStart;
    if (startIso != null && startIso.isNotEmpty) {
      final start = DateTime.tryParse(startIso);
      if (start == null) return strings.planned(startIso);
      final startLabel = DeviceDateFormat.dateTime(context, start);
      final endIso = task.plannedEnd;
      final end = endIso == null || endIso.isEmpty
          ? null
          : DateTime.tryParse(endIso);
      if (end == null) return strings.planned(startLabel);
      return strings.plannedRange(
        startLabel,
        DeviceDateFormat.dateTime(context, end),
      );
    }
    final planned = task.plannedDate;
    if (planned != null) {
      return strings.planned(DeviceDateFormat.dateIso(context, planned));
    }
    final due = task.dueDate;
    if (due != null) {
      final parsed = _dueDateTime();
      final time = _dueTimeLabel(context);
      if (parsed != null && dateKey(parsed) == _todayKey()) {
        // A task due today only needs its time; the date is implied.
        return time ?? strings.filterToday;
      }
      final date = DeviceDateFormat.dateIso(context, due);
      if (time == null) return strings.due(date);
      return strings.dueAt(date, time);
    }
    return null;
  }

  Widget? _trailing(TasksStrings strings, ColorScheme scheme) {
    final pin = task.pinned;
    final dragIndex = reorderIndex;
    if (!pin && dragIndex == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pin)
          Semantics(
            container: true,
            label: strings.pinned,
            child: ExcludeSemantics(
              child: Tooltip(
                message: strings.pinned,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.x4),
                  child: Icon(
                    Icons.push_pin,
                    size: DsIcon.sm,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        if (dragIndex != null)
          ReorderableDragStartListener(
            key: ValueKey('task-drag-${task.id}'),
            index: dragIndex,
            child: Semantics(
              container: true,
              label: strings.reorderTask(task.title),
              child: const ExcludeSemantics(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.drag_handle, size: DsIcon.sm),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.alignment,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.x24),
      child: Icon(icon, color: foreground),
    );
  }
}
