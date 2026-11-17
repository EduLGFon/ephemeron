// Slipped-task derivation for the Stream surface.
//
// Open tasks are sourced from [openTasksProvider] and filtered to those whose
// dueDate or plannedDate is before the local current day. This file is the
// stable entry point for slipped data, actions and the repository gateway.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drift/app_database.dart' show Task, TaskList;
import '../../tasks/application/tasks_providers.dart'
    show openTasksProvider, taskListsByIdProvider;
import '../presentation/slipped/slipped_item.dart';
import 'stream_slipped_clock.dart';
import 'stream_slipped_color.dart';
import 'stream_slipped_dates.dart';

export 'stream_slipped_actions.dart';
export 'stream_slipped_clock.dart';
export 'stream_slipped_gateway.dart';
export 'stream_slipped_result.dart';

final streamSlippedItemsProvider = StreamProvider<List<SlippedItem>>((ref) {
  final listsById = ref.watch(taskListsByIdProvider);
  final today = ref.watch(streamSlippedClockProvider)();
  final controller = StreamController<List<SlippedItem>>();
  ref.onDispose(controller.close);
  ref.listen<AsyncValue<List<Task>>>(openTasksProvider(null), (_, next) {
    next.when(
      data: (tasks) {
        if (controller.isClosed) return;
        controller.add(
          mapSlippedItems(tasks, listsById: listsById, today: today),
        );
      },
      error: (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      },
      loading: () {},
    );
  }, fireImmediately: true);
  return controller.stream;
});

/// Maps open tasks to triage rows. Completed/deleted rows are ignored even if
/// a caller supplies them, and duplicate ids collapse to the most overdue row.
List<SlippedItem> mapSlippedItems(
  List<Task> tasks, {
  required Map<String, TaskList> listsById,
  required DateTime today,
}) {
  final byId = <String, SlippedItem>{};
  for (final task in tasks) {
    if (task.completedAt != null || task.deletedAt != null) continue;
    final days = slippedDaysOverdue(
      today: today,
      dueDate: task.dueDate,
      plannedDate: task.plannedDate,
    );
    if (days == null) continue;
    final item = SlippedItem(
      id: task.id,
      title: task.title,
      daysOverdue: days,
      listColorArgb: slippedListColorArgb(listsById[task.listId]),
    );
    final existing = byId[task.id];
    if (existing == null || _compareSlipped(item, existing) < 0) {
      byId[task.id] = item;
    }
  }
  final items = byId.values.toList()..sort(_compareSlipped);
  return List<SlippedItem>.unmodifiable(items);
}

int _compareSlipped(SlippedItem a, SlippedItem b) {
  final byDays = b.daysOverdue.compareTo(a.daysOverdue);
  if (byDays != 0) return byDays;
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (byTitle != 0) return byTitle;
  return a.id.compareTo(b.id);
}
