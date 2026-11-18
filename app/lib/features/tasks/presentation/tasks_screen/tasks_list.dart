part of '../tasks_screen.dart';

/// Effective date used for Today/Upcoming filters. A planned date wins over
/// the deadline, matching the calendar's task occurrence rule.
String? _effectiveTaskDate(Task task) {
  final start = task.plannedStart;
  if (start != null && start.length >= 10) return start.substring(0, 10);
  return task.plannedDate ?? task.dueDate;
}

bool _isOverdueTask(Task task, String today) {
  if (task.completedAt != null) return false;
  final due = task.dueDate;
  return due != null && due.compareTo(today) < 0;
}

List<Task> _visibleTasks({
  required List<Task> tasks,
  required _TaskFilter filter,
  required String query,
  required String today,
  required TaskSort? sort,
}) {
  final needle = query.toLowerCase();
  final visible = <Task>[];
  for (final task in tasks) {
    if (filter == _TaskFilter.completed) {
      if (task.completedAt == null) continue;
    } else if (filter == _TaskFilter.today || filter == _TaskFilter.upcoming) {
      if (task.completedAt != null) continue;
      final date = _effectiveTaskDate(task);
      if (date == null) continue;
      final compare = date.compareTo(today);
      if (filter == _TaskFilter.today ? compare > 0 : compare <= 0) continue;
    }
    if (needle.isNotEmpty && !_matchesQuery(task, needle)) continue;
    visible.add(task);
  }
  if (sort != null) visible.sort((a, b) => compareTasks(a, b, sort));
  return visible;
}

bool _matchesQuery(Task task, String needle) {
  if (task.title.toLowerCase().contains(needle)) return true;
  final notes = task.notes;
  return notes != null && notes.toLowerCase().contains(needle);
}

class _TasksList extends StatelessWidget {
  const _TasksList({
    required this.tasks,
    required this.overdueIds,
    required this.listsById,
    required this.onRescheduleAll,
  });

  final List<Task> tasks;
  final Set<String> overdueIds;
  final Map<String, TaskList> listsById;
  final VoidCallback? onRescheduleAll;

  @override
  Widget build(BuildContext context) {
    final overdue = <Task>[];
    final rest = <Task>[];
    for (final task in tasks) {
      (overdueIds.contains(task.id) ? overdue : rest).add(task);
    }
    final ordered = [...overdue, ...rest];
    final hasHeader = overdue.isNotEmpty;
    return RepaintBoundary(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: DsSpace.x24),
        itemCount: ordered.length + (hasHeader ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasHeader && index == 0) {
            return _OverdueHeader(
              count: overdue.length,
              onRescheduleAll: onRescheduleAll,
            );
          }
          final task = ordered[index - (hasHeader ? 1 : 0)];
          return _TaskItem(
            key: ValueKey('task-${task.id}'),
            task: task,
            list: task.listId == null ? null : listsById[task.listId],
            overdue: overdueIds.contains(task.id),
          );
        },
      ),
    );
  }
}

class _OverdueHeader extends StatelessWidget {
  const _OverdueHeader({required this.count, required this.onRescheduleAll});

  final int count;
  final VoidCallback? onRescheduleAll;

  @override
  Widget build(BuildContext context) {
    final strings = TasksStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.x8),
      child: SectionTitle(
        title: strings.overdue,
        count: count,
        action: AppIconButton(
          icon: Icons.event_repeat,
          tooltip: strings.rescheduleAll,
          semanticLabel: strings.rescheduleAll,
          onPressed: onRescheduleAll,
        ),
      ),
    );
  }
}

class _TasksEmpty extends StatelessWidget {
  const _TasksEmpty({
    required this.filter,
    required this.query,
    required this.smart,
    required this.onAddTask,
    required this.onManageLists,
    required this.onCloseSearch,
    required this.onEditSmart,
  });

  final _TaskFilter filter;
  final String query;
  final SmartList? smart;
  final VoidCallback onAddTask;
  final VoidCallback onManageLists;
  final VoidCallback onCloseSearch;
  final VoidCallback onEditSmart;

  @override
  Widget build(BuildContext context) {
    final strings = TasksStrings.of(context);
    if (query.isNotEmpty) {
      return AppEmptyState(
        icon: Icons.search_off,
        title: strings.searchEmptyTitle,
        message: strings.searchEmptyMessage(query),
        actionLabel: strings.closeSearch,
        onAction: onCloseSearch,
      );
    }
    if (smart != null) {
      return AppEmptyState(
        icon: Icons.filter_alt_off,
        title: strings.noMatchesTitle,
        message: strings.noMatchesMessage(smart!.name),
        actionLabel: strings.editSmartList,
        onAction: onEditSmart,
      );
    }
    return switch (filter) {
      _TaskFilter.today => AppEmptyState(
        icon: Icons.today_outlined,
        title: strings.todayEmptyTitle,
        message: strings.todayEmptyMessage,
        actionLabel: strings.addTask,
        onAction: onAddTask,
      ),
      _TaskFilter.upcoming => AppEmptyState(
        icon: Icons.event_outlined,
        title: strings.upcomingEmptyTitle,
        message: strings.upcomingEmptyMessage,
        actionLabel: strings.addTask,
        onAction: onAddTask,
      ),
      _TaskFilter.completed => AppEmptyState(
        icon: Icons.check_circle_outline,
        title: strings.completedEmptyTitle,
        message: strings.completedEmptyMessage,
      ),
      _TaskFilter.all => AppEmptyState(
        icon: Icons.checklist_outlined,
        title: strings.emptyTitle,
        message: strings.emptyMessage,
        actionLabel: strings.addTask,
        onAction: onAddTask,
        secondaryLabel: strings.manageListsAction,
        onSecondary: onManageLists,
      ),
    };
  }
}
