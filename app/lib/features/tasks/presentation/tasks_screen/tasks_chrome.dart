part of '../tasks_screen.dart';

class _TasksHeader extends ConsumerWidget {
  const _TasksHeader({required this.canSort, required this.onAction});

  final bool canSort;
  final ValueChanged<_TasksAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = TasksStrings.of(context);
    final searchOpen = ref.watch(
      _taskSearchProvider.select((state) => state.open),
    );
    final sort = ref.watch(taskSortProvider).value ?? TaskSort.due;
    return AppPageHeader(
      title: Text(strings.title),
      actions: [
        AppIconButton(
          key: const ValueKey('tasks-search'),
          icon: Icons.search,
          tooltip: strings.search,
          semanticLabel: strings.search,
          selected: searchOpen,
          onPressed: () => ref.read(_taskSearchProvider.notifier).toggle(),
        ),
        if (canSort)
          PopupMenuButton<TaskSort>(
            key: const ValueKey('tasks-sort'),
            icon: const Icon(Icons.sort, size: DsIcon.md),
            tooltip: strings.sortTasks,
            initialValue: sort,
            onSelected: (mode) =>
                ref.read(taskSortProvider.notifier).select(mode),
            itemBuilder: (_) => [
              for (final mode in TaskSort.values)
                PopupMenuItem(
                  value: mode,
                  child: Text(strings.sortLabel(mode)),
                ),
            ],
          ),
        PopupMenuButton<_TasksAction>(
          key: const ValueKey('tasks-more'),
          icon: const Icon(Icons.more_vert, size: DsIcon.md),
          tooltip: strings.moreActions,
          onSelected: onAction,
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _TasksAction.manageLists,
              child: Text(strings.manageLists),
            ),
            PopupMenuItem(
              value: _TasksAction.manageSmartLists,
              child: Text(strings.manageSmartLists),
            ),
            PopupMenuItem(
              value: _TasksAction.trash,
              child: Text(strings.trash),
            ),
          ],
        ),
      ],
    );
  }
}

class _TaskListStrip extends StatelessWidget {
  const _TaskListStrip({
    required this.lists,
    required this.smartLists,
    required this.selectedListId,
    required this.selectedSmartId,
    required this.onSelectList,
    required this.onSelectSmart,
    required this.onManageLists,
    required this.onCreateList,
    required this.onCreateSmart,
    required this.onSmartLongPress,
  });

  final List<TaskList> lists;
  final List<SmartList> smartLists;
  final String? selectedListId;
  final String? selectedSmartId;
  final ValueChanged<String?> onSelectList;
  final ValueChanged<String> onSelectSmart;
  final VoidCallback onManageLists;
  final VoidCallback onCreateList;
  final VoidCallback onCreateSmart;
  final ValueChanged<SmartList> onSmartLongPress;

  @override
  Widget build(BuildContext context) {
    final strings = TasksStrings.of(context);
    final smartMode = selectedSmartId != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: DsSpace.x4),
      child: Row(
        children: [
          AppChip(
            key: const ValueKey('task-list-all'),
            label: strings.allLists,
            selected: selectedListId == null && !smartMode,
            onTap: () => onSelectList(null),
          ),
          for (final list in lists) ...[
            const SizedBox(width: DsSpace.x8),
            Tooltip(
              // Long press opens list management, so keep touch long-press out
              // of the tooltip. Hover still reveals the source account.
              triggerMode: TooltipTriggerMode.manual,
              message: _listSourceLabel(list, strings),
              child: AppChip(
                key: ValueKey('task-list-${list.id}'),
                label: list.name,
                color: taskListColor(list),
                selected: !smartMode && selectedListId == list.id,
                onTap: () => onSelectList(list.id),
                onLongPress: onManageLists,
              ),
            ),
          ],
          for (final smartList in smartLists) ...[
            const SizedBox(width: DsSpace.x8),
            _SmartListChip(
              smartList: smartList,
              selected: smartMode && selectedSmartId == smartList.id,
              onSelected: () => onSelectSmart(smartList.id),
              onLongPress: () => onSmartLongPress(smartList),
            ),
          ],
          const SizedBox(width: DsSpace.x8),
          AppChip(
            key: const ValueKey('task-list-new'),
            label: strings.newList,
            icon: Icons.add,
            dense: true,
            onTap: onCreateList,
          ),
          const SizedBox(width: DsSpace.x8),
          AppChip(
            key: const ValueKey('task-smart-new'),
            label: strings.newSmartList,
            icon: Icons.add,
            dense: true,
            onTap: onCreateSmart,
          ),
        ],
      ),
    );
  }

  String _listSourceLabel(TaskList list, TasksStrings strings) {
    return taskListAccountLabel(list) ??
        (list.remoteId == null ? localSourceLabel : strings.syncedList);
  }
}

class _TaskFilterStrip extends StatelessWidget {
  const _TaskFilterStrip({required this.filter, required this.onSelected});

  final _TaskFilter filter;
  final ValueChanged<_TaskFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = TasksStrings.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: DsSpace.x4),
      child: Row(
        children: [
          for (final value in _TaskFilter.values) ...[
            if (value != _TaskFilter.values.first)
              const SizedBox(width: DsSpace.x8),
            AppFilterChip(
              key: ValueKey('task-filter-${value.name}'),
              label: _filterLabel(strings, value),
              selected: filter == value,
              onSelected: (_) => onSelected(value),
            ),
          ],
        ],
      ),
    );
  }
}

String _filterLabel(TasksStrings strings, _TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all => strings.filterAll,
    _TaskFilter.today => strings.filterToday,
    _TaskFilter.upcoming => strings.filterUpcoming,
    _TaskFilter.completed => strings.filterCompleted,
  };
}

class _TasksSearchBar extends ConsumerStatefulWidget {
  const _TasksSearchBar({required this.initialQuery});

  final String initialQuery;

  @override
  ConsumerState<_TasksSearchBar> createState() => _TasksSearchBarState();
}

class _TasksSearchBarState extends ConsumerState<_TasksSearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = TasksStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.x4),
      child: AppSearchField(
        controller: _controller,
        hintText: strings.searchHint,
        autofocus: true,
        onChanged: (value) =>
            ref.read(_taskSearchProvider.notifier).setQuery(value),
        onClear: () => ref.read(_taskSearchProvider.notifier).setQuery(''),
      ),
    );
  }
}
