// Typed creation plans for capture drafts. Pure Dart: no Flutter, Riverpod or
// repositories. Executors resolve names to ids and persist the fields.
//
// Repository conventions reused here:
// - Task planned intervals are local ISO strings (YYYY-MM-DDTHH:mm) and replace
//   the all-day plannedDate, matching the task editor. Capture has one
//   date/time slot and no deadline marker, so CaptureTaskPlan has no due fields.
// - All-day dates and habit start dates are local YYYY-MM-DD keys. All-day
//   event end dates are exclusive (the next day), matching the event editor.
// - Habit weekdays use bits 1 << (DateTime.weekday - 1); daily repeats use
//   frequency 'daily', weekday repeats use 'weekdays' with a mask.
// - Unknown weekday values are ignored. A weekly repeat with no valid weekday
//   becomes FREQ=WEEKLY; a habit weekly repeat falls back to the start date.
import '../../../core/time/picker_memory.dart' show formatHhmm, formatYmd;
import '../capture/capture_kind.dart';
import '../capture/capture_parser.dart' show CaptureDraft;
import '../capture/capture_priority.dart';
import '../capture/capture_repeat.dart';

part 'stream_capture_plan_build.dart';

enum CapturePlanFailure { emptyTitle, endBeforeStart, missingDate }

class CapturePlanException implements Exception {
  const CapturePlanException(this.reason);

  final CapturePlanFailure reason;

  @override
  String toString() => 'CapturePlanException(${reason.name})';
}

sealed class CapturePlan {
  const CapturePlan({required this.title});

  final String title;
}

final class CaptureTaskPlan extends CapturePlan {
  const CaptureTaskPlan({
    required super.title,
    required this.listName,
    required this.priority,
    this.plannedDate,
    this.plannedStart,
    this.plannedEnd,
    this.rrule,
  });

  final String listName;
  final int priority;
  final String? plannedDate;
  final String? plannedStart;
  final String? plannedEnd;
  final String? rrule;
}

final class CaptureEventPlan extends CapturePlan {
  const CaptureEventPlan({
    required super.title,
    required this.calendarName,
    required this.allDay,
    this.start,
    this.end,
    this.startDate,
    this.endDate,
    this.rrule,
  });

  final String calendarName;
  final bool allDay;
  final DateTime? start;
  final DateTime? end;
  final String? startDate;
  final String? endDate;
  final String? rrule;
}

final class CaptureHabitPlan extends CapturePlan {
  const CaptureHabitPlan({
    required super.title,
    required this.frequency,
    required this.weekdaysMask,
    required this.startDate,
    this.reminderTime,
  });

  final String frequency;
  final int weekdaysMask;
  final String startDate;
  final String? reminderTime;
}

final class CaptureCountdownPlan extends CapturePlan {
  const CaptureCountdownPlan({required super.title, required this.targetDate});

  final String targetDate;
}

CapturePlan buildCapturePlan(
  CaptureDraft draft, {
  required DateTime now,
  required String defaultListName,
  required String defaultCalendarName,
}) {
  final title = draft.title.trim();
  if (title.isEmpty) {
    throw const CapturePlanException(CapturePlanFailure.emptyTitle);
  }
  return switch (draft.kind) {
    CaptureKind.task => _taskPlan(
      draft,
      title: title,
      defaultListName: defaultListName,
    ),
    CaptureKind.event => _eventPlan(
      draft,
      title: title,
      now: now,
      defaultCalendarName: defaultCalendarName,
    ),
    CaptureKind.habit => _habitPlan(draft, title: title, now: now),
    CaptureKind.countdown => _countdownPlan(draft, title: title),
  };
}
