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

CapturePlan _plan(CaptureDraft draft) {
  return buildCapturePlan(
    draft,
    now: _now,
    defaultListName: 'Inbox',
    defaultCalendarName: 'Personal',
  );
}

T _typed<T extends CapturePlan>(CapturePlan plan) {
  expect(plan, isA<T>());
  return plan as T;
}

void main() {
  group('task plan', () {
    test('timed task uses planned interval strings', () {
      final plan = _typed<CaptureTaskPlan>(
        _plan(
          _draft(
            title: '  call dentist  ',
            date: DateTime(2026, 11, 18),
            start: DateTime(2026, 11, 18, 15, 0),
            end: DateTime(2026, 11, 18, 16, 30),
          ),
        ),
      );
      expect(plan.title, 'call dentist');
      expect(plan.listName, 'Inbox');
      expect(plan.priority, 0);
      expect(plan.plannedDate, isNull);
      expect(plan.plannedStart, '2026-11-18T15:00');
      expect(plan.plannedEnd, '2026-11-18T16:30');
      expect(plan.rrule, isNull);
    });

    test('all-day task uses planned date', () {
      final plan = _typed<CaptureTaskPlan>(
        _plan(_draft(date: DateTime(2026, 11, 18))),
      );
      expect(plan.plannedDate, '2026-11-18');
      expect(plan.plannedStart, isNull);
      expect(plan.plannedEnd, isNull);
    });

    test('unscheduled task has no date fields', () {
      final plan = _typed<CaptureTaskPlan>(_plan(_draft()));
      expect(plan.plannedDate, isNull);
      expect(plan.plannedStart, isNull);
      expect(plan.plannedEnd, isNull);
      expect(plan.rrule, isNull);
    });

    test('priority mapping is 0/1/2/4', () {
      const expected = {
        CapturePriority.none: 0,
        CapturePriority.low: 1,
        CapturePriority.medium: 2,
        CapturePriority.high: 4,
      };
      for (final entry in expected.entries) {
        final plan = _typed<CaptureTaskPlan>(
          _plan(_draft(priority: entry.key)),
        );
        expect(plan.priority, entry.value, reason: entry.key.name);
      }
    });

    test('list tag overrides the default list name', () {
      final plan = _typed<CaptureTaskPlan>(_plan(_draft(listTag: ' Errands ')));
      expect(plan.listName, 'Errands');
    });

    test('blank list tag falls back to the default list name', () {
      final plan = _typed<CaptureTaskPlan>(_plan(_draft(listTag: '   ')));
      expect(plan.listName, 'Inbox');
    });

    test('daily repeat becomes FREQ=DAILY', () {
      final plan = _typed<CaptureTaskPlan>(
        _plan(
          _draft(
            date: DateTime(2026, 11, 18),
            repeat: const CaptureRepeat(
              frequency: CaptureRepeatFrequency.daily,
            ),
          ),
        ),
      );
      expect(plan.rrule, 'FREQ=DAILY');
    });

    test('weekly repeat without weekdays becomes FREQ=WEEKLY', () {
      final plan = _typed<CaptureTaskPlan>(
        _plan(
          _draft(
            date: DateTime(2026, 11, 18),
            repeat: const CaptureRepeat(
              frequency: CaptureRepeatFrequency.weekly,
            ),
          ),
        ),
      );
      expect(plan.rrule, 'FREQ=WEEKLY');
    });

    test('weekly weekdays are deduped and Monday-first', () {
      final plan = _typed<CaptureTaskPlan>(
        _plan(
          _draft(
            date: DateTime(2026, 11, 18),
            repeat: const CaptureRepeat(
              frequency: CaptureRepeatFrequency.weekly,
              weekdays: [
                DateTime.friday,
                DateTime.monday,
                DateTime.wednesday,
                DateTime.monday,
              ],
            ),
          ),
        ),
      );
      expect(plan.rrule, 'FREQ=WEEKLY;BYDAY=MO,WE,FR');
    });

    test('end before start is rejected', () {
      expect(
        () => _plan(
          _draft(
            date: DateTime(2026, 11, 18),
            start: DateTime(2026, 11, 18, 15, 0),
            end: DateTime(2026, 11, 18, 14, 0),
          ),
        ),
        throwsA(
          isA<CapturePlanException>().having(
            (e) => e.reason,
            'reason',
            CapturePlanFailure.endBeforeStart,
          ),
        ),
      );
    });
  });

  group('event plan', () {
    test('timed event keeps local start and end', () {
      final plan = _typed<CaptureEventPlan>(
        _plan(
          _draft(
            kind: CaptureKind.event,
            title: 'standup',
            date: DateTime(2026, 11, 18),
            start: DateTime(2026, 11, 18, 9, 0),
            end: DateTime(2026, 11, 18, 9, 15),
          ),
        ),
      );
      expect(plan.title, 'standup');
      expect(plan.calendarName, 'Personal');
      expect(plan.allDay, isFalse);
      expect(plan.start, DateTime(2026, 11, 18, 9, 0));
      expect(plan.end, DateTime(2026, 11, 18, 9, 15));
      expect(plan.startDate, isNull);
      expect(plan.endDate, isNull);
    });

    test('event without an end defaults to one hour', () {
      final plan = _typed<CaptureEventPlan>(
        _plan(
          _draft(
            kind: CaptureKind.event,
            date: DateTime(2026, 11, 18),
            start: DateTime(2026, 11, 18, 9, 0),
          ),
        ),
      );
      expect(plan.end, DateTime(2026, 11, 18, 10, 0));
    });

    test('all-day event uses exclusive end date', () {
      final plan = _typed<CaptureEventPlan>(
        _plan(_draft(kind: CaptureKind.event, date: DateTime(2026, 12, 31))),
      );
      expect(plan.allDay, isTrue);
      expect(plan.start, isNull);
      expect(plan.end, isNull);
      expect(plan.startDate, '2026-12-31');
      expect(plan.endDate, '2027-01-01');
    });

    test('event without a date falls back to today', () {
      final plan = _typed<CaptureEventPlan>(
        _plan(_draft(kind: CaptureKind.event)),
      );
      expect(plan.allDay, isTrue);
      expect(plan.startDate, '2026-11-17');
      expect(plan.endDate, '2026-11-18');
    });

    test('event repeat carries the RRULE', () {
      final plan = _typed<CaptureEventPlan>(
        _plan(
          _draft(
            kind: CaptureKind.event,
            date: DateTime(2026, 11, 18),
            start: DateTime(2026, 11, 18, 9, 0),
            end: DateTime(2026, 11, 18, 10, 0),
            repeat: const CaptureRepeat(
              frequency: CaptureRepeatFrequency.weekly,
              weekdays: [DateTime.monday],
            ),
          ),
        ),
      );
      expect(plan.rrule, 'FREQ=WEEKLY;BYDAY=MO');
    });

    test('end before start is rejected', () {
      expect(
        () => _plan(
          _draft(
            kind: CaptureKind.event,
            date: DateTime(2026, 11, 18),
            start: DateTime(2026, 11, 18, 10, 0),
            end: DateTime(2026, 11, 18, 9, 0),
          ),
        ),
        throwsA(isA<CapturePlanException>()),
      );
    });
  });

  group('habit plan', () {
    test('weekly weekdays map to the habit weekday mask', () {
      final plan = _typed<CaptureHabitPlan>(
        _plan(
          _draft(
            kind: CaptureKind.habit,
            title: 'gym',
            date: DateTime(2026, 11, 18),
            start: DateTime(2026, 11, 18, 7, 0),
            repeat: const CaptureRepeat(
              frequency: CaptureRepeatFrequency.weekly,
              weekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
            ),
          ),
        ),
      );
      expect(plan.title, 'gym');
      expect(plan.frequency, 'weekdays');
      expect(plan.weekdaysMask, (1 << 0) | (1 << 2) | (1 << 4));
      expect(plan.reminderTime, '07:00');
      expect(plan.startDate, '2026-11-18');
    });

    test('daily repeat maps to daily frequency', () {
      final plan = _typed<CaptureHabitPlan>(
        _plan(
          _draft(
            kind: CaptureKind.habit,
            repeat: const CaptureRepeat(
              frequency: CaptureRepeatFrequency.daily,
            ),
          ),
        ),
      );
      expect(plan.frequency, 'daily');
      expect(plan.weekdaysMask, 0);
      expect(plan.startDate, '2026-11-17');
      expect(plan.reminderTime, isNull);
    });

    test('weekly repeat without weekdays follows the start date', () {
      final plan = _typed<CaptureHabitPlan>(
        _plan(
          _draft(
            kind: CaptureKind.habit,
            date: DateTime(2026, 11, 19),
            repeat: const CaptureRepeat(
              frequency: CaptureRepeatFrequency.weekly,
            ),
          ),
        ),
      );
      expect(plan.frequency, 'weekdays');
      expect(plan.weekdaysMask, 1 << (DateTime.thursday - 1));
    });
  });

  group('countdown plan', () {
    test('target date is a date key', () {
      final plan = _typed<CaptureCountdownPlan>(
        _plan(
          _draft(
            kind: CaptureKind.countdown,
            title: 'trip',
            date: DateTime(2026, 12, 25),
          ),
        ),
      );
      expect(plan.title, 'trip');
      expect(plan.targetDate, '2026-12-25');
    });

    test('missing target date is rejected', () {
      expect(
        () => _plan(_draft(kind: CaptureKind.countdown, title: 'trip')),
        throwsA(
          isA<CapturePlanException>().having(
            (e) => e.reason,
            'reason',
            CapturePlanFailure.missingDate,
          ),
        ),
      );
    });
  });

  test('empty title is rejected', () {
    expect(
      () => _plan(_draft(title: '   ')),
      throwsA(
        isA<CapturePlanException>().having(
          (e) => e.reason,
          'reason',
          CapturePlanFailure.emptyTitle,
        ),
      ),
    );
  });
}
