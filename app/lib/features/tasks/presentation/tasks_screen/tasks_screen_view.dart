part of '../tasks_screen.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = TasksStrings.of(context);
    final listId = ref.watch(selectedTaskListProvider);
    final selectedSmartId = ref.watch(selectedSmartListProvider);
    final smartLists =
        ref.watch(smartListsProvider).value ?? const <SmartList>[];
    final smart = selectedSmartId == null
        ? null
        : smartLists.where((s) => s.id == selectedSmartId).firstOrNull;
    final filter = ref.watch(_taskFilterProvider);
    final search = ref.watch(_taskSearchProvider);
    final listsAsync = ref.watch(taskListsProvider);
    final listsById = ref.watch(taskListsByIdProvider);
    final taskSort = ref.watch(taskSortProvider).value ?? TaskSort.due;
    final listSort =
        ref.watch(taskListSortProvider).value ?? TaskListSort.custom;
    final lists = listsAsync.value ?? const <TaskList>[];
    final sortedLists = [...lists]
      ..sort((a, b) => compareTaskLists(a, b, listSort));

    final AsyncValue<List<Task>> source;
    if (smart != null) {
      source = ref.watch(smartListTasksProvider(smart));
    } else if (filter == _TaskFilter.completed) {
      source = ref.watch(completedProvider(listId));
    } else {
      source = ref.watch(openTasksProvider(listId));
    }

    final today = dateKey(DateTime.now());
    final query = search.query.trim();
    // Smart lists keep their saved sort. Completed rows keep their completion
    // order. Custom order is only meaningful for the unfiltered list.
    final sortForView = smart == null && filter != _TaskFilter.completed
        ? taskSort
        : null;
    final reorder =
        smart == null &&
        filter == _TaskFilter.all &&
        taskSort == TaskSort.custom &&
        query.isEmpty;

    return AppPage(
      header: _TasksHeader(
        canSort: smart == null,
        onAction: (action) => _onAction(context, ref, action),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TaskListStrip(
            lists: sortedLists,
            smartLists: smartLists,
            selectedListId: listId,
            selectedSmartId: smart?.id,
            onSelectList: (id) => _select(ref, id),
            onSelectSmart: (id) => _selectSmart(ref, id),
            onManageLists: () => _openLists(context),
            onCreateList: () => showCreateTaskListDialog(context, ref),
            onCreateSmart: () => showSmartListEditor(context),
            onSmartLongPress: (smartList) =>
                _smartActions(context, ref, smartList),
          ),
          _TaskFilterStrip(
            filter: filter,
            onSelected: (value) =>
                ref.read(_taskFilterProvider.notifier).select(value),
          ),
          if (search.open) _TasksSearchBar(initialQuery: search.query),
          const SizedBox(height: DsSpace.x4),
          Expanded(
            child: source.when(
              loading: () => const AppSkeletonList(rows: 6),
              error: (_, _) => AppErrorState(
                title: strings.errorTitle,
                message: strings.errorMessage,
                onRetry: () => _retryTasks(ref, smart, listId, filter),
              ),
              data: (tasks) {
                final visible = _visibleTasks(
                  tasks: tasks,
                  filter: filter,
                  query: query,
                  today: today,
                  sort: sortForView,
                );
                if (visible.isEmpty) {
                  return _TasksEmpty(
                    filter: filter,
                    query: query,
                    smart: smart,
                    onAddTask: () => showQuickAdd(context),
                    onManageLists: () => _openLists(context),
                    onCloseSearch: () =>
                        ref.read(_taskSearchProvider.notifier).close(),
                    onEditSmart: () =>
                        showSmartListEditor(context, smartList: smart),
                  );
                }
                if (reorder) {
                  return _CustomTaskList(tasks: visible, listsById: listsById);
                }
                final overdue =
                    smart == null &&
                        filter == _TaskFilter.all &&
                        sortForView != TaskSort.custom
                    ? visible
                          .where((task) => _isOverdueTask(task, today))
                          .toList(growable: false)
                    : const <Task>[];
                return _TasksList(
                  tasks: visible,
                  overdueIds: {for (final task in overdue) task.id},
                  listsById: listsById,
                  onRescheduleAll: overdue.isEmpty
                      ? null
                      : () => _rescheduleAll(context, ref, overdue),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void _retryTasks(
  WidgetRef ref,
  SmartList? smart,
  String? listId,
  _TaskFilter filter,
) {
  if (smart != null) {
    ref.invalidate(smartListTasksProvider(smart));
  } else if (filter == _TaskFilter.completed) {
    ref.invalidate(completedProvider(listId));
  } else {
    ref.invalidate(openTasksProvider(listId));
  }
}
