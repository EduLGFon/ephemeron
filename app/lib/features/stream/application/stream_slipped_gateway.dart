// Narrow repository facade for slipped-task triage.
//
// Actions own the calendar math; this gateway owns persistence, pending-delete
// hygiene and occurrence-cache rebuilds.
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/db_provider.dart';
import '../../../data/drift/app_database.dart' show AppDatabase, Task, TaskList;
import '../../../data/repositories/occurrence_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../calendar/application/calendar_providers.dart'
    show occurrenceRepositoryProvider;
import '../../sync/application/pending_operations.dart'
    show PendingOperations, pendingOperationsProvider;
import '../../tasks/application/tasks_providers.dart'
    show taskListsByIdProvider, taskRepositoryProvider;
import 'stream_slipped_color.dart';

/// Immutable snapshot of the task fields triage needs.
class StreamSlippedTask {
  const StreamSlippedTask({
    required this.id,
    required this.listColorArgb,
    this.dueDate,
    this.plannedDate,
    this.plannedStart,
    this.plannedEnd,
  });

  final String id;
  final int listColorArgb;
  final String? dueDate;
  final String? plannedDate;
  final String? plannedStart;
  final String? plannedEnd;
}

abstract interface class StreamSlippedGateway {
  Future<StreamSlippedTask?> taskById(String id);
  Future<void> completeTask(String id);
  Future<void> uncompleteTask(String id);
  Future<void> updateTask(
    String id, {
    required String? dueDate,
    required String? plannedDate,
    required String? plannedStart,
    required String? plannedEnd,
  });
  Future<void> softDeleteTask(String id);
  Future<void> restoreTask(String id);
  Future<void> rebuildDay(DateTime localDay);
}

class RiverpodStreamSlippedGateway implements StreamSlippedGateway {
  RiverpodStreamSlippedGateway(
    this._db,
    this._tasks,
    this._listsById,
    this._occurrences,
    this._pending,
  );

  final AppDatabase _db;
  final TaskRepository _tasks;
  final Map<String, TaskList> _listsById;
  final OccurrenceRepository _occurrences;
  final PendingOperations _pending;

  @override
  Future<StreamSlippedTask?> taskById(String id) async {
    final open = await _tasks.watchOpen().first;
    for (final task in open) {
      if (task.id == id) return _snapshot(task);
    }
    return null;
  }

  StreamSlippedTask _snapshot(Task task) => StreamSlippedTask(
    id: task.id,
    listColorArgb: slippedListColorArgb(_listsById[task.listId]),
    dueDate: task.dueDate,
    plannedDate: task.plannedDate,
    plannedStart: task.plannedStart,
    plannedEnd: task.plannedEnd,
  );

  @override
  Future<void> completeTask(String id) async {
    await _cancelPendingDeletes(id);
    await _tasks.completeTask(id);
  }

  @override
  Future<void> uncompleteTask(String id) async {
    await _cancelPendingDeletes(id);
    await _tasks.uncompleteTask(id);
  }

  @override
  Future<void> updateTask(
    String id, {
    required String? dueDate,
    required String? plannedDate,
    required String? plannedStart,
    required String? plannedEnd,
  }) async {
    await _cancelPendingDeletes(id);
    await _tasks.updateTask(
      id,
      dueDate: () => dueDate,
      plannedDate: () => plannedDate,
      plannedStart: () => plannedStart,
      plannedEnd: () => plannedEnd,
    );
  }

  @override
  Future<void> softDeleteTask(String id) async {
    await _cancelPendingDeletes(id);
    await _tasks.softDeleteTasks([id]);
  }

  @override
  Future<void> restoreTask(String id) async {
    await _cancelPendingDeletes(id);
    await _tasks.restoreTasks([id]);
  }

  @override
  Future<void> rebuildDay(DateTime localDay) async {
    // UTC padding covers every local offset around the affected day.
    final day = DateTime.utc(localDay.year, localDay.month, localDay.day);
    await _occurrences.rebuildWindow(
      windowStartUtc: day.subtract(const Duration(days: 1)),
      windowEndUtc: day.add(const Duration(days: 2)),
    );
  }

  /// A triage mutation supersedes a delete queued by another surface.
  Future<void> _cancelPendingDeletes(String taskId) async {
    final rows =
        await (_db.select(_db.pendingOperations)
              ..where(
                (row) =>
                    row.entity.equals('task') &
                    row.entityId.equals(taskId) &
                    row.op.equals('delete'),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.scheduledAt)]))
            .get();
    await _pending.cancelAll(rows.map((row) => row.id));
  }
}

final streamSlippedGatewayProvider = Provider<StreamSlippedGateway>((ref) {
  return RiverpodStreamSlippedGateway(
    ref.watch(appDatabaseProvider),
    ref.watch(taskRepositoryProvider),
    ref.watch(taskListsByIdProvider),
    ref.watch(occurrenceRepositoryProvider),
    ref.watch(pendingOperationsProvider),
  );
});
