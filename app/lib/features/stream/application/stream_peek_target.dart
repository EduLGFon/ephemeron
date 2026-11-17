// Maps a Stream day mark to the Peek editor snapshot.
//
// Pure mapping plus provider lookups; no UI, no repository writes.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drift/app_database.dart' show Task, TaskList;
import '../../tasks/application/tasks_providers.dart'
    show openTasksProvider, taskListsProvider;
import '../presentation/peek/peek_data.dart';
import 'stream_day_mark.dart';

/// A Peek snapshot plus the repository identity it may be saved through.
///
/// Events are read-only in this unit: occurrence editing needs a scope
/// (single/series) that the Peek surface does not choose yet.
class StreamPeekTarget {
  const StreamPeekTarget({
    required this.data,
    required this.editable,
    this.sourceTaskId,
    this.sourcePriority,
  });

  final PeekData data;
  final bool editable;
  final String? sourceTaskId;

  /// Stored task priority (0 none, 1 low, 2 medium, 3 P2, 4 P1).
  ///
  /// Peek collapses 3 and 4 into [PeekPriority.high]. Keeping the original
  /// value lets save preserve it when the user does not change the level.
  final int? sourcePriority;
}

/// Maps [mark] to PeekData.
///
/// Task marks resolve the task through [openTasksProvider] so title, list,
/// priority and notes reflect local edits that have not rebuilt the
/// occurrence cache yet. Times come from the mark, which already carries the
/// local epoch milliseconds rendered on the Stream, so the editor matches the
/// visible block. Event marks map read-only and have no list or task id.
/// A task mark whose task is no longer open returns null.
final streamPeekTargetProvider =
    FutureProvider.family<StreamPeekTarget?, StreamDayMark>((ref, mark) async {
      switch (mark.kind) {
        case StreamDayMarkKind.event:
          return StreamPeekTarget(
            data: PeekData(
              id: mark.id,
              title: mark.title,
              startMs: mark.startMs,
              endMs: mark.endMs,
            ),
            editable: false,
          );
        case StreamDayMarkKind.task:
          return _taskTarget(ref, mark);
      }
    });

Future<StreamPeekTarget?> _taskTarget(Ref ref, StreamDayMark mark) async {
  final taskId = mark.sourceTaskOrEventId;
  if (taskId == null) return null;
  final tasks = await ref.watch(openTasksProvider(null).future);
  final task = _findTask(tasks, taskId);
  if (task == null) return null;
  final listName = task.listId == null
      ? null
      : _listName(await ref.watch(taskListsProvider.future), task.listId!);
  return StreamPeekTarget(
    data: PeekData(
      id: task.id,
      title: task.title,
      startMs: mark.startMs,
      endMs: mark.endMs,
      listId: task.listId,
      listName: listName,
      priority: _peekPriority(task.priority),
      notes: task.notes,
    ),
    editable: true,
    sourceTaskId: task.id,
    sourcePriority: task.priority,
  );
}

Task? _findTask(List<Task> tasks, String id) {
  for (final task in tasks) {
    if (task.id == id) return task;
  }
  return null;
}

String? _listName(List<TaskList> lists, String id) {
  for (final list in lists) {
    if (list.id == id) return list.name;
  }
  return null;
}

// Stored priorities are 0 none, 1 low, 2 medium, 3 P2, 4 P1. Peek has four
// levels, so 3 and 4 both map to high. Save preserves the stored value when
// the level is unchanged; selecting high explicitly writes 4 (P1).
PeekPriority _peekPriority(int priority) => switch (priority) {
  <= 0 => PeekPriority.none,
  1 => PeekPriority.low,
  2 => PeekPriority.medium,
  _ => PeekPriority.high,
};
