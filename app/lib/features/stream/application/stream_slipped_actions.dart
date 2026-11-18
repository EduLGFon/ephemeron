// Triage mutations for slipped tasks. No UI, feedback or navigation here.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time.dart';
import 'stream_slipped_clock.dart';
import 'stream_slipped_dates.dart';
import 'stream_slipped_gateway.dart';
import 'stream_slipped_result.dart';

class StreamSlippedActions {
  StreamSlippedActions(this._gateway, {StreamSlippedClock? clock})
    : _clock = clock ?? DateTime.now;

  final StreamSlippedGateway _gateway;
  final StreamSlippedClock _clock;

  Future<StreamSlippedResult> done(String id) async {
    final task = await _requireTask(id);
    final days = _daysOf(task);
    await _guard(() => _gateway.completeTask(id));
    await _rebuild(days);
    return StreamSlippedResult(
      taskId: id,
      undo: () async {
        await _guard(() => _gateway.uncompleteTask(id));
        await _rebuild(days);
      },
    );
  }

  Future<StreamSlippedResult> tomorrow(String id) async {
    final task = await _requireTask(id);
    final target = nextLocalDay(_clock());
    final nextDue = shiftDateKeyToDay(task.dueDate, target);
    final nextPlanned = shiftDateKeyToDay(task.plannedDate, target);
    final nextStart = shiftLocalIsoToDay(task.plannedStart, target);
    final nextEnd = shiftLocalIsoToDay(task.plannedEnd, target);
    final oldDays = _daysOf(task);
    final newDays = slippedAffectedDays(
      dueDate: nextDue,
      plannedDate: nextPlanned,
      plannedStart: nextStart,
    );
    final affected = {...oldDays, ...newDays};
    await _guard(
      () => _gateway.updateTask(
        id,
        dueDate: nextDue,
        plannedDate: nextPlanned,
        plannedStart: nextStart,
        plannedEnd: nextEnd,
      ),
    );
    await _rebuild(affected);
    return StreamSlippedResult(
      taskId: id,
      undo: () async {
        await _guard(
          () => _gateway.updateTask(
            id,
            dueDate: task.dueDate,
            plannedDate: task.plannedDate,
            plannedStart: task.plannedStart,
            plannedEnd: task.plannedEnd,
          ),
        );
        await _rebuild(affected);
      },
    );
  }

  Future<StreamSlippedResult> pickTime(
    String id,
    DateTime start, {
    Duration duration = const Duration(minutes: 30),
  }) async {
    final task = await _requireTask(id);
    final localStart = start.isUtc ? start.toLocal() : start;
    final plannedDate = dateKey(localStart);
    final plannedStart = formatLocalIso(localStart);
    final plannedEnd = formatLocalIso(localStart.add(duration));
    final oldDays = _daysOf(task);
    final newDays = slippedAffectedDays(
      dueDate: task.dueDate,
      plannedDate: plannedDate,
      plannedStart: plannedStart,
    );
    final affected = {...oldDays, ...newDays};
    await _guard(
      () => _gateway.updateTask(
        id,
        dueDate: task.dueDate,
        plannedDate: plannedDate,
        plannedStart: plannedStart,
        plannedEnd: plannedEnd,
      ),
    );
    await _rebuild(affected);
    return StreamSlippedResult(
      taskId: id,
      undo: () async {
        await _guard(
          () => _gateway.updateTask(
            id,
            dueDate: task.dueDate,
            plannedDate: task.plannedDate,
            plannedStart: task.plannedStart,
            plannedEnd: task.plannedEnd,
          ),
        );
        await _rebuild(affected);
      },
    );
  }

  Future<StreamSlippedResult> drop(String id) async {
    final task = await _requireTask(id);
    final days = _daysOf(task);
    await _guard(() => _gateway.softDeleteTask(id));
    await _rebuild(days);
    return StreamSlippedResult(
      taskId: id,
      undo: () async {
        await _guard(() => _gateway.restoreTask(id));
        await _rebuild(days);
      },
    );
  }

  Future<StreamSlippedTask> _requireTask(String id) async {
    final task = await _guard(() => _gateway.taskById(id));
    if (task == null) throw StreamSlippedException.missingTask(id);
    return task;
  }

  Set<DateTime> _daysOf(StreamSlippedTask task) => slippedAffectedDays(
    dueDate: task.dueDate,
    plannedDate: task.plannedDate,
    plannedStart: task.plannedStart,
  );

  Future<void> _rebuild(Set<DateTime> days) async {
    final ordered = days.toList()..sort();
    for (final day in ordered) {
      await _guard(() => _gateway.rebuildDay(day));
    }
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on StreamSlippedException {
      rethrow;
    } catch (error, stack) {
      throw StreamSlippedException.repository(cause: error, stackTrace: stack);
    }
  }
}

final streamSlippedActionsProvider = Provider<StreamSlippedActions>((ref) {
  return StreamSlippedActions(
    ref.watch(streamSlippedGatewayProvider),
    clock: ref.watch(streamSlippedClockProvider),
  );
});
