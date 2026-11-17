// Narrow repository gateway for capture execution. The application layer
// depends on this interface so tests can inject a fake without Drift.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/application/calendar_providers.dart';
import '../../countdowns/application/countdowns_providers.dart';
import '../../habits/application/habits_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import 'stream_capture_plan.dart';

class StreamCaptureList {
  const StreamCaptureList({required this.id, required this.name});

  final String id;
  final String name;
}

class StreamCaptureCalendar {
  const StreamCaptureCalendar({
    required this.id,
    required this.name,
    required this.readOnly,
  });

  final String id;
  final String name;
  final bool readOnly;
}

abstract interface class StreamCaptureGateway {
  Future<List<StreamCaptureList>> taskLists();

  Future<String> createTaskList(String name);

  Future<String?> defaultCalendarId();

  Future<List<StreamCaptureCalendar>> calendars();

  Future<String> createCalendar(String name);

  Future<String> createTask(String listId, CaptureTaskPlan plan);

  Future<String> createEvent(String calendarId, CaptureEventPlan plan);

  Future<String> createHabit(CaptureHabitPlan plan);

  Future<String> createCountdown(CaptureCountdownPlan plan);

  /// Marks occurrences dirty and rebuilds the cache around [day] so the new
  /// task or event is visible without waiting for the next navigation.
  Future<void> refreshDay(DateTime day);
}

class RepositoryStreamCaptureGateway implements StreamCaptureGateway {
  RepositoryStreamCaptureGateway(this._ref);

  final Ref _ref;

  @override
  Future<List<StreamCaptureList>> taskLists() async {
    final lists = await _ref.read(taskListsProvider.future);
    return [
      for (final list in lists) StreamCaptureList(id: list.id, name: list.name),
    ];
  }

  @override
  Future<String> createTaskList(String name) =>
      _ref.read(taskRepositoryProvider).createList(name);

  @override
  Future<String?> defaultCalendarId() async {
    final settings = await _ref.read(settingsRepositoryProvider.future);
    return settings.defaultCalendarId;
  }

  @override
  Future<List<StreamCaptureCalendar>> calendars() async {
    final calendars = await _ref.read(calendarsProvider.future);
    return [
      for (final calendar in calendars)
        if (calendar.deletedAt == null)
          StreamCaptureCalendar(
            id: calendar.id,
            name: calendar.name,
            readOnly: calendar.readOnly,
          ),
    ];
  }

  @override
  Future<String> createCalendar(String name) =>
      _ref.read(eventRepositoryProvider).createCalendar(name);

  @override
  Future<String> createTask(String listId, CaptureTaskPlan plan) {
    return _ref
        .read(taskRepositoryProvider)
        .createTask(
          title: plan.title,
          listId: listId,
          priority: plan.priority,
          plannedDate: plan.plannedDate,
          plannedStart: plan.plannedStart,
          plannedEnd: plan.plannedEnd,
          rrule: plan.rrule,
        );
  }

  @override
  Future<String> createEvent(String calendarId, CaptureEventPlan plan) {
    return _ref
        .read(eventRepositoryProvider)
        .createEvent(
          calendarId: calendarId,
          title: plan.title,
          startUtc: plan.start?.toUtc(),
          endUtc: plan.end?.toUtc(),
          startDate: plan.startDate,
          endDate: plan.endDate,
          allDay: plan.allDay,
          rrule: plan.rrule,
        );
  }

  @override
  Future<String> createHabit(CaptureHabitPlan plan) {
    return _ref
        .read(habitRepositoryProvider)
        .createHabit(
          name: plan.title,
          frequency: plan.frequency,
          weekdaysMask: plan.weekdaysMask,
          startDate: plan.startDate,
          reminderTime: plan.reminderTime,
        );
  }

  @override
  Future<String> createCountdown(CaptureCountdownPlan plan) {
    return _ref
        .read(countdownRepositoryProvider)
        .createCountdown(title: plan.title, targetDate: plan.targetDate);
  }

  @override
  Future<void> refreshDay(DateTime day) async {
    // Set dirty first: if the rebuild fails, the calendar screen still retries.
    _ref.read(occurrenceDirtyProvider.notifier).markDirty();
    await _ref
        .read(occurrenceRepositoryProvider)
        .rebuildWindow(
          windowStartUtc: DateTime.utc(day.year, day.month, day.day - 1),
          windowEndUtc: DateTime.utc(day.year, day.month, day.day + 2),
        );
  }
}

final streamCaptureGatewayProvider = Provider<StreamCaptureGateway>((ref) {
  return RepositoryStreamCaptureGateway(ref);
});
