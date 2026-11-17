part of 'stream_capture_plan.dart';

CaptureTaskPlan _taskPlan(
  CaptureDraft draft, {
  required String title,
  required String defaultListName,
}) {
  final tag = draft.listTag?.trim();
  final listName = tag == null || tag.isEmpty ? defaultListName : tag;
  final start = draft.startTime;
  final end = draft.endTime;
  if (start != null && end != null && !end.isAfter(start)) {
    throw const CapturePlanException(CapturePlanFailure.endBeforeStart);
  }
  return CaptureTaskPlan(
    title: title,
    listName: listName,
    priority: _priorityValue(draft.priority),
    plannedDate: start == null && draft.date != null
        ? formatYmd(draft.date!)
        : null,
    plannedStart: start == null ? null : _localIso(start),
    plannedEnd: end == null ? null : _localIso(end),
    rrule: _rrule(draft.repeat),
  );
}

CaptureEventPlan _eventPlan(
  CaptureDraft draft, {
  required String title,
  required DateTime now,
  required String defaultCalendarName,
}) {
  final start = draft.startTime;
  final rrule = _rrule(draft.repeat);
  if (start == null) {
    final day = _dayOf(draft.date ?? now);
    return CaptureEventPlan(
      title: title,
      calendarName: defaultCalendarName,
      allDay: true,
      startDate: formatYmd(day),
      endDate: formatYmd(day.add(const Duration(days: 1))),
      rrule: rrule,
    );
  }
  // The event editor also defaults a missing end to one hour after start.
  final end = draft.endTime ?? start.add(const Duration(hours: 1));
  if (!end.isAfter(start)) {
    throw const CapturePlanException(CapturePlanFailure.endBeforeStart);
  }
  return CaptureEventPlan(
    title: title,
    calendarName: defaultCalendarName,
    allDay: false,
    start: start,
    end: end,
    rrule: rrule,
  );
}

CaptureHabitPlan _habitPlan(
  CaptureDraft draft, {
  required String title,
  required DateTime now,
}) {
  final startDay = _dayOf(draft.date ?? now);
  final repeat = draft.repeat;
  final isWeekly = repeat?.frequency == CaptureRepeatFrequency.weekly;
  final reminder = draft.startTime;
  return CaptureHabitPlan(
    title: title,
    frequency: isWeekly ? 'weekdays' : 'daily',
    weekdaysMask: isWeekly
        ? _weekdaysMask(repeat!, fallbackWeekday: startDay.weekday)
        : 0,
    startDate: formatYmd(startDay),
    reminderTime: reminder == null
        ? null
        : formatHhmm(reminder.hour, reminder.minute),
  );
}

CaptureCountdownPlan _countdownPlan(
  CaptureDraft draft, {
  required String title,
}) {
  final date = draft.date;
  if (date == null) {
    throw const CapturePlanException(CapturePlanFailure.missingDate);
  }
  return CaptureCountdownPlan(title: title, targetDate: formatYmd(date));
}

// 0 none, 1 P4, 2 P3, 3 P2, 4 P1. Capture's three levels use P4/P3/P1;
// P2 stays available only through the task editor's explicit chip.
int _priorityValue(CapturePriority priority) => switch (priority) {
  CapturePriority.none => 0,
  CapturePriority.low => 1,
  CapturePriority.medium => 2,
  CapturePriority.high => 4,
};

String? _rrule(CaptureRepeat? repeat) {
  if (repeat == null) return null;
  switch (repeat.frequency) {
    case CaptureRepeatFrequency.daily:
      return 'FREQ=DAILY';
    case CaptureRepeatFrequency.weekly:
      final codes = <String>[];
      for (final weekday in _sortedUnique(repeat.weekdays)) {
        final code = _weekdayCodes[weekday];
        if (code != null) codes.add(code);
      }
      if (codes.isEmpty) return 'FREQ=WEEKLY';
      return 'FREQ=WEEKLY;BYDAY=${codes.join(',')}';
  }
}

int _weekdaysMask(CaptureRepeat repeat, {required int fallbackWeekday}) {
  var mask = 0;
  for (final weekday in repeat.weekdays) {
    if (weekday >= DateTime.monday && weekday <= DateTime.sunday) {
      mask |= 1 << (weekday - 1);
    }
  }
  // A weekly repeat without usable weekdays follows the start date.
  return mask == 0 ? 1 << (fallbackWeekday - 1) : mask;
}

List<int> _sortedUnique(List<int> values) {
  final unique = values.toSet().toList()..sort();
  return unique;
}

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

String _localIso(DateTime value) =>
    '${formatYmd(value)}T${formatHhmm(value.hour, value.minute)}';

const Map<int, String> _weekdayCodes = {
  DateTime.monday: 'MO',
  DateTime.tuesday: 'TU',
  DateTime.wednesday: 'WE',
  DateTime.thursday: 'TH',
  DateTime.friday: 'FR',
  DateTime.saturday: 'SA',
  DateTime.sunday: 'SU',
};
