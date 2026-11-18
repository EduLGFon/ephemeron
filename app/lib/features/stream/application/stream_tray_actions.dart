// Stream tray actions: schedule or unschedule a task at a drop time through
// the existing task repository and occurrence cache. Application layer only.
//
// Field mapping matches the task editor's planned interval:
// - plannedStart/plannedEnd: local ISO 'YYYY-MM-DDTHH:mm', minute precision.
// - plannedDate: cleared when a timed interval is set.
// - dueTime: minutes of day (0..1439) taken from the start.
// Unschedule clears plannedStart, plannedEnd and plannedDate; dueTime is left
// untouched because updateTask treats a null callback as "no change" and a
// due time without a due date is a harmless time-of-day preference.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/picker_memory.dart' show formatHhmm, formatYmd;
import '../../../data/drift/app_database.dart' show Task;
import '../../../data/repositories/occurrence_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../calendar/application/calendar_providers.dart'
    show occurrenceRepositoryProvider;
import '../../tasks/application/tasks_providers.dart'
    show openTasksProvider, taskRepositoryProvider;
import 'stream_day_providers.dart' show StreamDayKey, streamDayRange;
import 'stream_tray.dart' show isUnscheduledTask;

enum StreamTrayFailure { taskMissing, alreadyScheduled, updateFailed }

class StreamTrayException implements Exception {
  const StreamTrayException(this.reason, {this.cause});

  final StreamTrayFailure reason;
  final Object? cause;

  @override
  String toString() => 'StreamTrayException($reason)';
}

/// Narrow seam for tray actions. Tests replace it; the default delegates to
/// the existing repositories.
abstract interface class StreamTrayGateway {
  /// Writes the planned interval. plannedStart/End/Date null clears the field;
  /// dueTime null leaves the stored due time unchanged.
  Future<void> updateTask(
    String taskId, {
    required String? plannedStart,
    required String? plannedEnd,
    required String? plannedDate,
    int? dueTime,
  });

  /// Rebuilds occurrence-cache rows for [day] (a local date).
  Future<void> rebuildDay(DateTime day);
}

class RiverpodStreamTrayGateway implements StreamTrayGateway {
  RiverpodStreamTrayGateway(this._tasks, this._occurrences);

  final TaskRepository _tasks;
  final OccurrenceRepository _occurrences;

  @override
  Future<void> updateTask(
    String taskId, {
    required String? plannedStart,
    required String? plannedEnd,
    required String? plannedDate,
    int? dueTime,
  }) {
    return _tasks.updateTask(
      taskId,
      plannedStart: () => plannedStart,
      plannedEnd: () => plannedEnd,
      plannedDate: () => plannedDate,
      dueTime: dueTime == null ? null : () => dueTime,
    );
  }

  @override
  Future<void> rebuildDay(DateTime day) async {
    final range = streamDayRange(
      StreamDayKey(year: day.year, month: day.month, day: day.day),
    );
    await _occurrences.rebuildWindow(
      windowStartUtc: range.fromUtc,
      windowEndUtc: range.toUtc,
    );
  }
}

final streamTrayGatewayProvider = Provider<StreamTrayGateway>((ref) {
  return RiverpodStreamTrayGateway(
    ref.watch(taskRepositoryProvider),
    ref.watch(occurrenceRepositoryProvider),
  );
});

final streamTrayActionsProvider = Provider<StreamTrayActions>(
  (ref) => StreamTrayActions(ref),
);

class StreamTrayActions {
  StreamTrayActions(this._ref);

  final Ref _ref;

  /// Schedules [taskId] at [start] for [duration].
  Future<void> scheduleTask(
    String taskId,
    DateTime start, {
    Duration duration = const Duration(minutes: 30),
  }) async {
    final task = await _task(taskId);
    if (!isUnscheduledTask(task)) {
      throw const StreamTrayException(StreamTrayFailure.alreadyScheduled);
    }
    final minuteStart = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
    );
    final gateway = _ref.read(streamTrayGatewayProvider);
    try {
      await gateway.updateTask(
        taskId,
        plannedStart: _localIso(minuteStart),
        plannedEnd: _localIso(minuteStart.add(duration)),
        plannedDate: null,
        dueTime: minuteStart.hour * 60 + minuteStart.minute,
      );
      await gateway.rebuildDay(_dayOf(minuteStart));
    } catch (error) {
      throw StreamTrayException(StreamTrayFailure.updateFailed, cause: error);
    }
  }

  /// Clears a tray-scheduled interval. No-op when there is no planned date.
  Future<void> unscheduleTask(String taskId) async {
    final task = await _task(taskId);
    final day = _plannedDay(task);
    if (day == null) return;
    final gateway = _ref.read(streamTrayGatewayProvider);
    try {
      await gateway.updateTask(
        taskId,
        plannedStart: null,
        plannedEnd: null,
        plannedDate: null,
      );
      await gateway.rebuildDay(day);
    } catch (error) {
      throw StreamTrayException(StreamTrayFailure.updateFailed, cause: error);
    }
  }

  Future<Task> _task(String taskId) async {
    final tasks = await _ref.read(openTasksProvider(null).future);
    for (final task in tasks) {
      if (task.id == taskId) return task;
    }
    throw const StreamTrayException(StreamTrayFailure.taskMissing);
  }
}

String _localIso(DateTime dt) =>
    '${formatYmd(dt)}T${formatHhmm(dt.hour, dt.minute)}';

DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

DateTime? _plannedDay(Task task) {
  final start = task.plannedStart;
  if (start != null && start.isNotEmpty) {
    final parsed = DateTime.tryParse(start);
    if (parsed != null) return _dayOf(parsed);
  }
  final planned = task.plannedDate;
  if (planned != null && planned.isNotEmpty) {
    final parsed = DateTime.tryParse(planned);
    if (parsed != null) return _dayOf(parsed);
  }
  return null;
}
