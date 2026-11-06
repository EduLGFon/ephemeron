import 'package:ephemeron/domain/alarms/alarm_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same day carries time', () {
    final now = DateTime(2026, 3, 2, 8, 0);
    final fire = DateTime(2026, 3, 2, 14, 0).toUtc().millisecondsSinceEpoch;
    expect(
      decorateAlarmTitle('Go to dentist', fire, now: now),
      'Go to dentist 14:00',
    );
  });

  test('tomorrow all-day label', () {
    final now = DateTime(2026, 3, 2, 8, 0);
    final fire = DateTime(2026, 3, 3, 9, 0).toUtc().millisecondsSinceEpoch;
    expect(
      decorateAlarmTitle("Hector's Birthday", fire, now: now, allDay: true),
      "Hector's Birthday Tomorrow",
    );
  });

  test('tomorrow timed label', () {
    final now = DateTime(2026, 3, 2, 8, 0);
    final fire = DateTime(2026, 3, 3, 14, 0).toUtc().millisecondsSinceEpoch;
    expect(
      decorateAlarmTitle('Go to dentist', fire, now: now),
      'Go to dentist 14:00 Tomorrow',
    );
  });

  test('empty title no leading space', () {
    final now = DateTime(2026, 3, 2, 8, 0);
    final fire = DateTime(2026, 3, 2, 14, 0).toUtc().millisecondsSinceEpoch;
    expect(decorateAlarmTitle('', fire, now: now), '14:00');
  });

  test('yesterday branch', () {
    final now = DateTime(2026, 3, 3, 8, 0);
    final fire = DateTime(2026, 3, 2, 14, 0).toUtc().millisecondsSinceEpoch;
    expect(decorateAlarmTitle('Past', fire, now: now), 'Past 14:00 Yesterday');
  });

  test('weekday branch', () {
    final now = DateTime(2026, 3, 2, 8, 0); // Monday
    final fire = DateTime(
      2026,
      3,
      4,
      14,
      0,
    ).toUtc().millisecondsSinceEpoch; // Wednesday
    expect(decorateAlarmTitle('Mid', fire, now: now), 'Mid 14:00 Wed');
  });

  test('d/m branch', () {
    final now = DateTime(2026, 3, 2, 8, 0);
    final fire = DateTime(2026, 4, 15, 14, 0).toUtc().millisecondsSinceEpoch;
    expect(decorateAlarmTitle('Far', fire, now: now), 'Far 14:00 15/4');
  });

  test('same-day all-day appends Today', () {
    final now = DateTime(2026, 3, 2, 8, 0);
    final fire = DateTime(2026, 3, 2, 9, 0).toUtc().millisecondsSinceEpoch;
    expect(
      decorateAlarmTitle('Holiday', fire, now: now, allDay: true),
      'Holiday Today',
    );
  });

  test('idempotency guard', () {
    final now = DateTime(2026, 3, 2, 8, 0);
    final fire = DateTime(2026, 3, 2, 14, 0).toUtc().millisecondsSinceEpoch;
    final once = decorateAlarmTitle('Go to dentist', fire, now: now);
    expect(decorateAlarmTitle(once, fire, now: now), once);
  });

  test('nowUtcMs injection path', () {
    final nowUtc = DateTime(
      2026,
      3,
      2,
      11,
      0,
    ).toUtc().millisecondsSinceEpoch; // 08:00 local -03
    final fire = DateTime(2026, 3, 2, 14, 0).toUtc().millisecondsSinceEpoch;
    expect(
      decorateAlarmTitle('Injected', fire, nowUtcMs: nowUtc),
      'Injected 14:00',
    );
  });

  test('due-tomorrow timed appends only time', () {
    final now = DateTime(2026, 3, 2, 8, 0);
    // fire is today (reminder fires day before due)
    final fire = DateTime(2026, 3, 2, 17, 0).toUtc().millisecondsSinceEpoch;
    expect(
      decorateAlarmTitle(
        'Due tomorrow: Task',
        fire,
        now: now,
        includeDayLabel: false,
      ),
      'Due tomorrow: Task 17:00',
    );
  });

  test('strip helper removes suffix', () {
    expect(
      stripAlarmTitleSuffix('Go to dentist 14:00 Tomorrow'),
      'Go to dentist',
    );
    expect(
      stripAlarmTitleSuffix('Due tomorrow: Task 17:00'),
      'Due tomorrow: Task',
    );
  });
}
