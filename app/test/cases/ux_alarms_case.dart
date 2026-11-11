import 'package:ephemeron/features/alarms/presentation/alarm_settings_format.dart';
import 'package:ephemeron/features/alarms/presentation/alarm_source_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('alarmSourceRoute', () {
    test('maps each source type to its section', () {
      expect(alarmSourceRoute('event'), '/tab0');
      expect(alarmSourceRoute('task'), '/tab1');
      expect(alarmSourceRoute('habit'), '/tab3');
      expect(alarmSourceRoute('habit_reminder'), '/tab3');
      expect(alarmSourceRoute('countdown'), '/tab4');
      expect(alarmSourceRoute('focus'), '/tab5');
      expect(alarmSourceRoute('test'), '/alarm-settings');
    });

    test('reminder variants follow their parent section', () {
      expect(alarmSourceRoute('event_reminder'), '/tab0');
      expect(alarmSourceRoute('task_reminder'), '/tab1');
      expect(alarmSourceRoute('task_due_tomorrow'), '/tab1');
      expect(alarmSourceRoute('countdown_reminder'), '/tab4');
    });

    test('null and unknown sources fall back to calendar', () {
      expect(alarmSourceRoute(null), '/tab0');
      expect(alarmSourceRoute(''), '/tab0');
      expect(alarmSourceRoute('unexpected'), '/tab0');
    });
  });

  group('alarmSourceLabel', () {
    test('labels known sources and their reminder variants', () {
      expect(alarmSourceLabel('event'), 'Event');
      expect(alarmSourceLabel('event_reminder'), 'Event');
      expect(alarmSourceLabel('task'), 'Task');
      expect(alarmSourceLabel('task_due_tomorrow'), 'Task');
      expect(alarmSourceLabel('habit'), 'Habit');
      expect(alarmSourceLabel('habit_reminder'), 'Habit');
      expect(alarmSourceLabel('countdown'), 'Countdown');
      expect(alarmSourceLabel('countdown_reminder'), 'Countdown');
      expect(alarmSourceLabel('focus'), 'Focus');
      expect(alarmSourceLabel('test'), 'Test');
    });

    test('unknown sources have no chip label', () {
      expect(alarmSourceLabel(null), isNull);
      expect(alarmSourceLabel('unexpected'), isNull);
    });
  });

  group('formatAlarmFireTime', () {
    test('converts UTC milliseconds to local time', () {
      final local = DateTime(2026, 3, 2, 14, 30);
      final ms = local.toUtc().millisecondsSinceEpoch;

      expect(
        formatAlarmFireTime(ms, DateFormat('yyyy-MM-dd HH:mm')),
        '2026-03-02 14:30',
      );
    });

    test('uses the supplied device formatter', () {
      final local = DateTime(2026, 11, 9, 7, 5);
      final ms = local.toUtc().millisecondsSinceEpoch;

      expect(
        formatAlarmFireTime(ms, DateFormat('yyyy/MM/dd HH:mm')),
        '2026/11/09 07:05',
      );
    });
  });
}
