// Narrow repository boundary for saving Stream Peek edits.
//
// The actions layer depends on this interface; production reads the existing
// task and occurrence repositories through Riverpod.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/application/calendar_providers.dart'
    show occurrenceRepositoryProvider;
import '../../tasks/application/tasks_providers.dart'
    show taskRepositoryProvider;

abstract interface class StreamPeekGateway {
  Future<void> updateTask({
    required String taskId,
    required String title,
    required String plannedStart,
    required String? plannedEnd,
    required String? listId,
    required int priority,
    required String? notes,
  });

  /// Rebuilds the occurrence cache for the local day containing [dayStartMs].
  Future<void> rebuildDay(int dayStartMs);
}

class RiverpodStreamPeekGateway implements StreamPeekGateway {
  RiverpodStreamPeekGateway(this._ref);

  final Ref _ref;

  @override
  Future<void> updateTask({
    required String taskId,
    required String title,
    required String plannedStart,
    required String? plannedEnd,
    required String? listId,
    required int priority,
    required String? notes,
  }) async {
    await _ref
        .read(taskRepositoryProvider)
        .updateTask(
          taskId,
          title: title,
          plannedStart: () => plannedStart,
          plannedEnd: () => plannedEnd,
          // A timed block replaces the legacy all-day planned date, matching
          // the task editor's save path.
          plannedDate: () => null,
          listId: listId,
          priority: priority,
          // updateTask treats null as "leave unchanged"; empty clears notes.
          notes: notes ?? '',
        );
  }

  @override
  Future<void> rebuildDay(int dayStartMs) async {
    final local = DateTime.fromMillisecondsSinceEpoch(dayStartMs);
    final dayStart = DateTime(local.year, local.month, local.day);
    // rebuildWindow deletes by a padded day key but inserts only rows that
    // overlap the window. Rebuild the same padded span so neighboring cache
    // days are not dropped.
    await _ref
        .read(occurrenceRepositoryProvider)
        .rebuildWindow(
          windowStartUtc: dayStart.subtract(const Duration(days: 1)),
          windowEndUtc: dayStart.add(const Duration(days: 2)),
        );
  }
}

final streamPeekGatewayProvider = Provider<StreamPeekGateway>((ref) {
  return RiverpodStreamPeekGateway(ref);
});
