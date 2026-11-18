import 'package:ephemeron/features/stream/application/stream_capture_actions.dart';
import 'package:ephemeron/features/stream/application/stream_capture_gateway.dart';
import 'package:ephemeron/features/stream/application/stream_capture_outcome.dart';
import 'package:ephemeron/features/stream/application/stream_capture_plan.dart';
import 'package:ephemeron/features/stream/capture/capture_kind.dart';
import 'package:ephemeron/features/stream/capture/capture_parser.dart';
import 'package:ephemeron/features/stream/capture/capture_priority.dart';
import 'package:ephemeron/features/stream/capture/capture_repeat.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime(2026, 11, 17, 9, 30);

CaptureDraft _draft({
  CaptureKind kind = CaptureKind.task,
  String title = 'write tests',
  DateTime? date,
  DateTime? start,
  DateTime? end,
  CaptureRepeat? repeat,
  String? listTag,
  CapturePriority priority = CapturePriority.none,
}) {
  return CaptureDraft(
    kind: kind,
    title: title,
    date: date,
    startTime: start,
    endTime: end,
    repeat: repeat,
    listTag: listTag,
    priority: priority,
  );
}

class _FakeGateway implements StreamCaptureGateway {
  List<StreamCaptureList> lists = const [];
  List<StreamCaptureCalendar> calendarChoices = const [];
  String? defaultCalendar;
  Object? listError;
  Object? calendarError;
  Object? createError;
  Object? refreshError;

  final List<String> createdLists = [];
  final List<String> createdCalendars = [];
  final List<DateTime> refreshedDays = [];
  String? taskListId;
  CaptureTaskPlan? taskPlan;
  String? eventCalendarId;
  CaptureEventPlan? eventPlan;
  CaptureHabitPlan? habitPlan;
  CaptureCountdownPlan? countdownPlan;

  @override
  Future<List<StreamCaptureList>> taskLists() async {
    if (listError != null) throw listError!;
    return lists;
  }

  @override
  Future<String> createTaskList(String name) async {
    if (listError != null) throw listError!;
    createdLists.add(name);
    return 'list-new';
  }

  @override
  Future<String?> defaultCalendarId() async {
    if (calendarError != null) throw calendarError!;
    return defaultCalendar;
  }

  @override
  Future<List<StreamCaptureCalendar>> calendars() async {
    if (calendarError != null) throw calendarError!;
    return calendarChoices;
  }

  @override
  Future<String> createCalendar(String name) async {
    if (calendarError != null) throw calendarError!;
    createdCalendars.add(name);
    return 'cal-new';
  }

  @override
  Future<String> createTask(String listId, CaptureTaskPlan plan) async {
    if (createError != null) throw createError!;
    taskListId = listId;
    taskPlan = plan;
    return 'task-1';
  }

  @override
  Future<String> createEvent(String calendarId, CaptureEventPlan plan) async {
    if (createError != null) throw createError!;
    eventCalendarId = calendarId;
    eventPlan = plan;
    return 'event-1';
  }

  @override
  Future<String> createHabit(CaptureHabitPlan plan) async {
    if (createError != null) throw createError!;
    habitPlan = plan;
    return 'habit-1';
  }

  @override
  Future<String> createCountdown(CaptureCountdownPlan plan) async {
    if (createError != null) throw createError!;
    countdownPlan = plan;
    return 'countdown-1';
  }

  @override
  Future<void> refreshDay(DateTime day) async {
    if (refreshError != null) throw refreshError!;
    refreshedDays.add(day);
  }
}

void main() {
  late _FakeGateway gateway;
  late StreamCaptureActions actions;

  setUp(() {
    gateway = _FakeGateway();
    actions = StreamCaptureActions(gateway);
  });

  test('creates a timed task on an existing list by name', () async {
    gateway.lists = const [StreamCaptureList(id: 'l1', name: 'Work')];
    final outcome = await actions.submit(
      _draft(
        title: 'call dentist',
        date: DateTime(2026, 11, 18),
        start: DateTime(2026, 11, 18, 15, 0),
        end: DateTime(2026, 11, 18, 16, 0),
        listTag: 'work',
        priority: CapturePriority.high,
        repeat: const CaptureRepeat(frequency: CaptureRepeatFrequency.daily),
      ),
      now: _now,
    );

    expect(outcome.kind, CaptureKind.task);
    expect(outcome.id, 'task-1');
    expect(outcome.scheduledDay, DateTime(2026, 11, 18));
    expect(gateway.createdLists, isEmpty);
    expect(gateway.taskListId, 'l1');
    expect(gateway.taskPlan!.title, 'call dentist');
    expect(gateway.taskPlan!.priority, 4);
    expect(gateway.taskPlan!.plannedStart, '2026-11-18T15:00');
    expect(gateway.taskPlan!.plannedEnd, '2026-11-18T16:00');
    expect(gateway.taskPlan!.rrule, 'FREQ=DAILY');
    expect(gateway.refreshedDays, [DateTime(2026, 11, 18)]);
  });

  test('creates a missing list before the task', () async {
    final outcome = await actions.submit(
      _draft(date: DateTime(2026, 11, 18), listTag: 'Errands'),
      now: _now,
    );

    expect(gateway.createdLists, ['Errands']);
    expect(gateway.taskListId, 'list-new');
    expect(outcome.id, 'task-1');
  });

  test('unscheduled tasks are not refreshed', () async {
    final outcome = await actions.submit(_draft(), now: _now);

    expect(outcome.scheduledDay, isNull);
    expect(gateway.refreshedDays, isEmpty);
  });

  test(
    'creates an event on the default calendar and rebuilds its day',
    () async {
      gateway.calendarChoices = const [
        StreamCaptureCalendar(id: 'cal-1', name: 'Work', readOnly: false),
        StreamCaptureCalendar(id: 'cal-2', name: 'Personal', readOnly: false),
      ];
      gateway.defaultCalendar = 'cal-2';
      final outcome = await actions.submit(
        _draft(
          kind: CaptureKind.event,
          title: 'standup',
          date: DateTime(2026, 11, 18),
          start: DateTime(2026, 11, 18, 9, 0),
          end: DateTime(2026, 11, 18, 9, 15),
        ),
        now: _now,
      );

      expect(outcome.kind, CaptureKind.event);
      expect(outcome.id, 'event-1');
      expect(outcome.scheduledDay, DateTime(2026, 11, 18));
      expect(gateway.createdCalendars, isEmpty);
      expect(gateway.eventCalendarId, 'cal-2');
      expect(gateway.eventPlan!.start, DateTime(2026, 11, 18, 9, 0));
      expect(gateway.eventPlan!.end, DateTime(2026, 11, 18, 9, 15));
      expect(gateway.refreshedDays, [DateTime(2026, 11, 18)]);
    },
  );

  test('falls back to the first writable calendar', () async {
    gateway.calendarChoices = const [
      StreamCaptureCalendar(id: 'cal-1', name: 'Holidays', readOnly: true),
      StreamCaptureCalendar(id: 'cal-2', name: 'Local', readOnly: false),
    ];
    gateway.defaultCalendar = 'cal-1';
    await actions.submit(
      _draft(
        kind: CaptureKind.event,
        date: DateTime(2026, 11, 18),
        start: DateTime(2026, 11, 18, 9, 0),
      ),
      now: _now,
    );

    expect(gateway.eventCalendarId, 'cal-2');
  });

  test('creates the caller default calendar when none is writable', () async {
    gateway.calendarChoices = const [
      StreamCaptureCalendar(id: 'cal-1', name: 'Holidays', readOnly: true),
    ];
    final outcome = await actions.submit(
      _draft(kind: CaptureKind.event, date: DateTime(2026, 11, 18)),
      now: _now,
    );

    expect(gateway.createdCalendars, ['Calendar']);
    expect(gateway.eventCalendarId, 'cal-new');
    expect(outcome.id, 'event-1');
  });

  test(
    'creates habits and countdowns without refreshing the calendar',
    () async {
      final habit = await actions.submit(
        _draft(
          kind: CaptureKind.habit,
          title: 'gym',
          date: DateTime(2026, 11, 18),
          start: DateTime(2026, 11, 18, 7, 0),
          repeat: const CaptureRepeat(
            frequency: CaptureRepeatFrequency.weekly,
            weekdays: [DateTime.monday, DateTime.friday],
          ),
        ),
        now: _now,
      );
      expect(habit.kind, CaptureKind.habit);
      expect(habit.scheduledDay, DateTime(2026, 11, 18));
      expect(gateway.habitPlan!.frequency, 'weekdays');
      expect(gateway.habitPlan!.weekdaysMask, (1 << 0) | (1 << 4));
      expect(gateway.habitPlan!.reminderTime, '07:00');

      final countdown = await actions.submit(
        _draft(
          kind: CaptureKind.countdown,
          title: 'trip',
          date: DateTime(2026, 12, 25),
        ),
        now: _now,
      );
      expect(countdown.kind, CaptureKind.countdown);
      expect(countdown.scheduledDay, DateTime(2026, 12, 25));
      expect(gateway.countdownPlan!.targetDate, '2026-12-25');
      expect(gateway.refreshedDays, isEmpty);
    },
  );

  test('maps plan failures to typed capture failures', () async {
    await expectLater(
      actions.submit(_draft(title: '  '), now: _now),
      throwsA(
        isA<StreamCaptureException>().having(
          (e) => e.reason,
          'reason',
          StreamCaptureFailure.emptyTitle,
        ),
      ),
    );
  });

  test('maps repository errors to typed capture failures', () async {
    final listError = StateError('lists unavailable');
    gateway.listError = listError;
    await expectLater(
      actions.submit(_draft(), now: _now),
      throwsA(
        isA<StreamCaptureException>()
            .having((e) => e.reason, 'reason', StreamCaptureFailure.listFailed)
            .having((e) => e.cause, 'cause', same(listError)),
      ),
    );

    gateway = _FakeGateway()..createError = StateError('insert failed');
    actions = StreamCaptureActions(gateway);
    await expectLater(
      actions.submit(_draft(), now: _now),
      throwsA(
        isA<StreamCaptureException>()
            .having(
              (e) => e.reason,
              'reason',
              StreamCaptureFailure.createFailed,
            )
            .having((e) => e.cause, 'cause', isA<StateError>()),
      ),
    );

    gateway = _FakeGateway()..refreshError = StateError('rebuild failed');
    actions = StreamCaptureActions(gateway);
    await expectLater(
      actions.submit(_draft(date: DateTime(2026, 11, 18)), now: _now),
      throwsA(
        isA<StreamCaptureException>().having(
          (e) => e.reason,
          'reason',
          StreamCaptureFailure.refreshFailed,
        ),
      ),
    );
  });
}
