// Executes a capture draft against repositories. No UI, navigation or
// snackbars: the surface decides how to present failures and outcomes.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/capture_kind.dart';
import '../capture/capture_parser.dart' show CaptureDraft;
import 'stream_capture_gateway.dart';
import 'stream_capture_outcome.dart';
import 'stream_capture_plan.dart';

class StreamCaptureActions {
  StreamCaptureActions(
    this._gateway, {
    this.defaultListName = 'Tasks',
    this.defaultCalendarName = 'Calendar',
  });

  final StreamCaptureGateway _gateway;
  final String defaultListName;
  final String defaultCalendarName;

  Future<CaptureOutcome> submit(
    CaptureDraft draft, {
    required DateTime now,
  }) async {
    final plan = _buildPlan(draft, now);
    return switch (plan) {
      CaptureTaskPlan() => _submitTask(plan),
      CaptureEventPlan() => _submitEvent(plan),
      CaptureHabitPlan() => _submitHabit(plan),
      CaptureCountdownPlan() => _submitCountdown(plan),
    };
  }

  CapturePlan _buildPlan(CaptureDraft draft, DateTime now) {
    try {
      return buildCapturePlan(
        draft,
        now: now,
        defaultListName: defaultListName,
        defaultCalendarName: defaultCalendarName,
      );
    } on CapturePlanException catch (error) {
      throw StreamCaptureException(_planFailure(error.reason));
    }
  }

  Future<CaptureOutcome> _submitTask(CaptureTaskPlan plan) async {
    final listId = await _resolveList(plan.listName);
    final id = await _create(() => _gateway.createTask(listId, plan));
    final day = _taskDay(plan);
    await _refresh(day);
    return CaptureOutcome(kind: CaptureKind.task, id: id, scheduledDay: day);
  }

  Future<CaptureOutcome> _submitEvent(CaptureEventPlan plan) async {
    final calendarId = await _resolveCalendar();
    final id = await _create(() => _gateway.createEvent(calendarId, plan));
    final day = plan.start != null
        ? _dayOf(plan.start!)
        : _parseDay(plan.startDate);
    await _refresh(day);
    return CaptureOutcome(kind: CaptureKind.event, id: id, scheduledDay: day);
  }

  Future<CaptureOutcome> _submitHabit(CaptureHabitPlan plan) async {
    final id = await _create(() => _gateway.createHabit(plan));
    return CaptureOutcome(
      kind: CaptureKind.habit,
      id: id,
      scheduledDay: _parseDay(plan.startDate),
    );
  }

  Future<CaptureOutcome> _submitCountdown(CaptureCountdownPlan plan) async {
    final id = await _create(() => _gateway.createCountdown(plan));
    return CaptureOutcome(
      kind: CaptureKind.countdown,
      id: id,
      scheduledDay: _parseDay(plan.targetDate),
    );
  }

  Future<String> _resolveList(String name) async {
    try {
      final lists = await _gateway.taskLists();
      final wanted = name.trim().toLowerCase();
      for (final list in lists) {
        if (list.name.trim().toLowerCase() == wanted) return list.id;
      }
      return await _gateway.createTaskList(name);
    } on StreamCaptureException {
      rethrow;
    } catch (error) {
      throw StreamCaptureException(
        StreamCaptureFailure.listFailed,
        cause: error,
      );
    }
  }

  Future<String> _resolveCalendar() async {
    try {
      final calendars = await _gateway.calendars();
      final defaultId = await _gateway.defaultCalendarId();
      if (defaultId != null) {
        for (final calendar in calendars) {
          if (calendar.id == defaultId && !calendar.readOnly) {
            return calendar.id;
          }
        }
      }
      for (final calendar in calendars) {
        if (!calendar.readOnly) return calendar.id;
      }
      return await _gateway.createCalendar(defaultCalendarName);
    } on StreamCaptureException {
      rethrow;
    } catch (error) {
      throw StreamCaptureException(
        StreamCaptureFailure.calendarFailed,
        cause: error,
      );
    }
  }

  Future<String> _create(Future<String> Function() create) async {
    try {
      return await create();
    } on StreamCaptureException {
      rethrow;
    } catch (error) {
      throw StreamCaptureException(
        StreamCaptureFailure.createFailed,
        cause: error,
      );
    }
  }

  Future<void> _refresh(DateTime? day) async {
    if (day == null) return;
    try {
      await _gateway.refreshDay(day);
    } on StreamCaptureException {
      rethrow;
    } catch (error) {
      throw StreamCaptureException(
        StreamCaptureFailure.refreshFailed,
        cause: error,
      );
    }
  }

  static DateTime? _taskDay(CaptureTaskPlan plan) {
    final start = plan.plannedStart;
    if (start != null) return _dayOf(DateTime.parse(start));
    return _parseDay(plan.plannedDate);
  }

  static DateTime? _parseDay(String? key) =>
      key == null ? null : _dayOf(DateTime.parse(key));

  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static StreamCaptureFailure _planFailure(CapturePlanFailure reason) {
    return switch (reason) {
      CapturePlanFailure.emptyTitle => StreamCaptureFailure.emptyTitle,
      CapturePlanFailure.endBeforeStart => StreamCaptureFailure.endBeforeStart,
      CapturePlanFailure.missingDate => StreamCaptureFailure.missingDate,
    };
  }
}

final streamCaptureActionsProvider = Provider<StreamCaptureActions>((ref) {
  return StreamCaptureActions(ref.watch(streamCaptureGatewayProvider));
});
