// Stream tray data: unscheduled open tasks as presentation chips.
//
// "Unscheduled" means the task has no plannedStart, plannedDate or dueDate.
// Items derive from openTasksProvider(null) and taskListsByIdProvider; no
// database or schema changes. Ordering is sortOrder, then title, then id, so
// repeated emissions produce the same tray.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../data/drift/app_database.dart' show Task, TaskList;
import '../../tasks/application/tasks_providers.dart'
    show openTasksProvider, taskListsByIdProvider, taskListsProvider;
import '../presentation/tray/tray_item.dart';

/// True when the task has no date/time at all (Stream tray definition).
bool isUnscheduledTask(Task task) =>
    _blank(task.plannedStart) &&
    _blank(task.plannedDate) &&
    _blank(task.dueDate);

bool _blank(String? value) => value == null || value.isEmpty;

/// Unscheduled tasks as tray chips. Waits for the list stream so the first
/// emission already has list names; empty when the task stream is loading.
final streamTrayItemsProvider = StreamProvider<List<TrayItem>>((ref) {
  final lists = ref.watch(taskListsProvider);
  if (!lists.hasValue && !lists.hasError) {
    return const Stream<List<TrayItem>>.empty();
  }
  final listsById = ref.watch(taskListsByIdProvider);
  return ref
      .watch(openTasksProvider(null))
      .when(
        data: (tasks) => Stream.value(buildStreamTrayItems(tasks, listsById)),
        loading: () => const Stream<List<TrayItem>>.empty(),
        error: (error, stackTrace) =>
            Stream<List<TrayItem>>.error(error, stackTrace),
      );
});

/// Pure mapping, exposed for tests. Duplicate ids keep the first item in
/// deterministic order.
List<TrayItem> buildStreamTrayItems(
  List<Task> tasks,
  Map<String, TaskList> listsById,
) {
  final eligible = tasks.where(isUnscheduledTask).toList(growable: false)
    ..sort(_compareTasks);
  final seen = <String>{};
  final items = <TrayItem>[];
  for (final task in eligible) {
    if (!seen.add(task.id)) continue;
    final listId = task.listId ?? '';
    final list = listsById[task.listId];
    items.add(
      TrayItem(
        id: task.id,
        title: task.title,
        listId: listId,
        listName: list?.name ?? listId,
        colorArgb: _listColorArgb(list, listId.isEmpty ? task.id : listId),
      ),
    );
  }
  return items;
}

int _compareTasks(Task a, Task b) {
  final sort = a.sortOrder.compareTo(b.sortOrder);
  if (sort != 0) return sort;
  final title = a.title.compareTo(b.title);
  if (title != 0) return title;
  final id = a.id.compareTo(b.id);
  if (id != 0) return id;
  return (a.listId ?? '').compareTo(b.listId ?? '');
}

/// Stored list colour when valid, else the stable preset fallback used by
/// the Tasks UI. Kept in the application layer to avoid importing widgets.
int _listColorArgb(TaskList? list, String seed) {
  final raw = list?.color;
  if (raw != null && isValidHex(raw)) return parseHex(raw).toARGB32();
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return primaryPresets[hash % primaryPresets.length].toARGB32();
}
