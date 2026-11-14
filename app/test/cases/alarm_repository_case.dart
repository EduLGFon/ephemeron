import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/alarms/data/alarm_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

String _tomorrowKey() {
  final t = DateTime.now().toUtc().add(const Duration(days: 1));
  return '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

/// Local "HH:mm" that is [ahead] from now, matching habit reminderTime.
String _localTimeAhead(Duration ahead) {
  final t = DateTime.now().add(ahead);
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

void main() {
  // Tests run with TargetPlatform.android, so AlarmScheduler reaches the
  // MethodChannel: stub it instead of touching the OS.
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ephemeron/alarms');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('task custom offsets schedule one reminder each', () async {
    final db = _db();
    addTearDown(db.close);
    final tasks = TaskRepository(db);
    final id = await tasks.createTask(
      title: 'Dentist',
      dueDate: _tomorrowKey(),
      dueTime: 12 * 60,
      reminders: '[30,0]',
      alarmPreset: 'full_short',
    );
    final n = await AlarmRepository(db).rebuildWindow();
    expect(n, greaterThanOrEqualTo(3));
    final rows = await (db.select(
      db.alarmsIndex,
    )..where((a) => a.sourceId.like('%$id%'))).get();
    final reminders = rows.where((r) => r.kind == 'reminder').toList();
    final alarms = rows.where((r) => r.kind == 'alarm').toList();
    expect(reminders.map((r) => r.sourceId), contains('$id#r30'));
    expect(reminders.map((r) => r.sourceId), contains('$id#r0'));
    expect(alarms.single.sourceId, id);
    expect(alarms.single.preset, 'full_short');
    // Reminder fires precede the alarm fire.
    final alarmFire = alarms.single.fireAtUtc;
    for (final r in reminders) {
      expect(r.fireAtUtc, lessThanOrEqualTo(alarmFire));
    }
  });

  test('task without reminders keeps at-time-only default', () async {
    final db = _db();
    addTearDown(db.close);
    final tasks = TaskRepository(db);
    final id = await tasks.createTask(
      title: 'Call',
      dueDate: _tomorrowKey(),
      dueTime: 9 * 60,
    );
    await AlarmRepository(db).rebuildWindow(dueTomorrowEnabled: false);
    final rows = await (db.select(
      db.alarmsIndex,
    )..where((a) => a.sourceId.like('%$id%'))).get();
    expect(rows.where((r) => r.kind == 'reminder'), hasLength(1));
    expect(rows.where((r) => r.kind == 'alarm'), isEmpty);
  });

  test('due-tomorrow candidates clamp to 09-17', () async {
    final db = _db();
    addTearDown(db.close);
    final tasks = TaskRepository(db);
    final dayAfter = () {
      final t = DateTime.now().toUtc().add(const Duration(days: 2));
      return '${t.year.toString().padLeft(4, '0')}-'
          '${t.month.toString().padLeft(2, '0')}-'
          '${t.day.toString().padLeft(2, '0')}';
    }();
    await tasks.createTask(title: 'Early', dueDate: dayAfter, dueTime: 8 * 60);
    await tasks.createTask(title: 'Noon', dueDate: dayAfter, dueTime: 12 * 60);
    await tasks.createTask(title: 'Late', dueDate: dayAfter, dueTime: 23 * 60);
    await tasks.createTask(title: 'None', dueDate: dayAfter);
    await AlarmRepository(db).rebuildWindow();
    final rows = await (db.select(
      db.alarmsIndex,
    )..where((a) => a.sourceType.equals('task_due_tomorrow'))).get();
    expect(rows, hasLength(4));
    final hours = rows
        .map(
          (r) => DateTime.fromMillisecondsSinceEpoch(
            r.fireAtUtc,
            isUtc: true,
          ).toLocal().hour,
        )
        .toSet();
    expect(hours, containsAll([9, 12, 17]));
  });

  test(
    'rebuildWindow dueTomorrowEnabled false adds no task_due_tomorrow',
    () async {
      final db = _db();
      addTearDown(db.close);
      final tasks = TaskRepository(db);
      await tasks.createTask(
        title: 'Tomorrow',
        dueDate: _tomorrowKey(),
        dueTime: 12 * 60,
      );
      await AlarmRepository(db).rebuildWindow(dueTomorrowEnabled: false);
      final rows = await (db.select(
        db.alarmsIndex,
      )..where((a) => a.sourceType.equals('task_due_tomorrow'))).get();
      expect(rows, isEmpty);
    },
  );

  test('habit with alarm preset schedules one alarm row', () async {
    final db = _db();
    addTearDown(db.close);
    final id = await HabitRepository(db).createHabit(
      name: 'Stretch',
      reminderTime: _localTimeAhead(const Duration(hours: 2)),
      alarmPreset: 'full_long',
    );
    await AlarmRepository(db).rebuildWindow(dueTomorrowEnabled: false);
    final rows = await (db.select(
      db.alarmsIndex,
    )..where((a) => a.sourceId.like('$id@%'))).get();
    expect(rows, hasLength(1));
    expect(rows.single.sourceType, 'habit');
    expect(rows.single.kind, 'alarm');
    expect(rows.single.preset, 'full_long');
  });

  for (final preset in <String?>['notification', null]) {
    test('habit with ${preset ?? 'no'} preset uses one reminder row', () async {
      final db = _db();
      addTearDown(db.close);
      final id = await HabitRepository(db).createHabit(
        name: 'Read',
        reminderTime: _localTimeAhead(const Duration(hours: 2)),
        alarmPreset: preset,
      );
      await AlarmRepository(db).rebuildWindow(dueTomorrowEnabled: false);
      final rows = await (db.select(
        db.alarmsIndex,
      )..where((a) => a.sourceId.like('$id@%'))).get();
      expect(rows, hasLength(1));
      expect(rows.single.sourceType, 'habit_reminder');
      expect(rows.single.kind, 'reminder');
      expect(rows.single.preset, 'notification');
    });
  }

  test('firing habit row blocks the next occurrence until dismissed', () async {
    final db = _db();
    addTearDown(db.close);
    final id = await HabitRepository(db).createHabit(
      name: 'Walk',
      reminderTime: _localTimeAhead(const Duration(hours: 2)),
    );
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    const firedId = 'habit-fired-today';
    await db
        .into(db.alarmsIndex)
        .insert(
          AlarmsIndexCompanion.insert(
            id: firedId,
            sourceType: 'habit_reminder',
            sourceId: '$id@$todayKey',
            fireAtUtc:
                DateTime.now().toUtc().millisecondsSinceEpoch - 60 * 1000,
            requestCode: const Value(9000),
            state: const Value('fired'),
            kind: const Value('reminder'),
            preset: const Value('notification'),
          ),
        );
    Future<List<AlarmsIndexData>> futureRows() {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      return (db.select(db.alarmsIndex)..where(
            (a) =>
                a.sourceId.like('$id@%') & a.fireAtUtc.isBiggerThanValue(now),
          ))
          .get();
    }

    await AlarmRepository(db).rebuildWindow(dueTomorrowEnabled: false);
    expect(await futureRows(), isEmpty);

    await (db.update(db.alarmsIndex)..where((a) => a.id.equals(firedId))).write(
      const AlarmsIndexCompanion(state: Value('dismissed')),
    );
    await AlarmRepository(db).rebuildWindow(dueTomorrowEnabled: false);
    final rows = await futureRows();
    expect(rows, hasLength(1));
    expect(rows.single.sourceType, 'habit_reminder');
  });

  test('preserves a ringing request code and plans around it', () async {
    final db = _db();
    addTearDown(db.close);
    const firedId = 'ringing';
    await db
        .into(db.alarmsIndex)
        .insert(
          AlarmsIndexCompanion.insert(
            id: firedId,
            sourceType: 'task_reminder',
            sourceId: 'old#r0',
            fireAtUtc:
                DateTime.now().toUtc().millisecondsSinceEpoch - 60 * 1000,
            requestCode: const Value(100000),
            state: const Value('fired'),
            kind: const Value('reminder'),
            preset: const Value('notification'),
          ),
        );
    await TaskRepository(
      db,
    ).createTask(title: 'Tomorrow', dueDate: _tomorrowKey(), dueTime: 23 * 60);
    final planned = await AlarmRepository(db)
        .rebuildWindow(dueTomorrowEnabled: false);
    expect(planned, 1);
    final preserved = await (db.select(
      db.alarmsIndex,
    )..where((a) => a.id.equals(firedId))).getSingleOrNull();
    expect(preserved, isNot(null));
    expect(preserved!.state, 'fired');
    expect(preserved.requestCode, 100000);
    final scheduled = await (db.select(
      db.alarmsIndex,
    )..where((a) => a.state.equals('scheduled'))).get();
    expect(scheduled.map((r) => r.requestCode), [100001]);
  });

  test(
    'snoozed rows survive rebuildWindow and keep their request code',
    () async {
      final db = _db();
      addTearDown(db.close);
      const snoozedId = 'snoozed-ring';
      await db
          .into(db.alarmsIndex)
          .insert(
            AlarmsIndexCompanion.insert(
              id: snoozedId,
              sourceType: 'task_reminder',
              sourceId: 'old#r0',
              fireAtUtc:
                  DateTime.now().toUtc().millisecondsSinceEpoch +
                  10 * 60 * 1000,
              requestCode: const Value(100000),
              state: const Value('snoozed'),
              kind: const Value('reminder'),
              preset: const Value('notification'),
            ),
          );
      await TaskRepository(db).createTask(
        title: 'Tomorrow',
        dueDate: _tomorrowKey(),
        dueTime: 23 * 60,
      );
      final planned = await AlarmRepository(db)
          .rebuildWindow(dueTomorrowEnabled: false);
      expect(planned, 1);
      final preserved = await (db.select(
        db.alarmsIndex,
      )..where((a) => a.id.equals(snoozedId))).getSingleOrNull();
      expect(preserved, isNot(null));
      expect(preserved!.state, 'snoozed');
      expect(preserved.requestCode, 100000);
      final scheduled = await (db.select(
        db.alarmsIndex,
      )..where((a) => a.state.equals('scheduled'))).get();
      expect(scheduled.map((r) => r.requestCode), [100001]);
    },
  );

  test('cancelForHabitDay removes a snoozed habit row', () async {
    final db = _db();
    addTearDown(db.close);
    await db
        .into(db.alarmsIndex)
        .insert(
          AlarmsIndexCompanion.insert(
            id: 'snoozed-habit',
            sourceType: 'habit_reminder',
            sourceId: 'h9@2026-01-02',
            fireAtUtc:
                DateTime.now().toUtc().millisecondsSinceEpoch + 10 * 60 * 1000,
            requestCode: const Value(3),
            state: const Value('snoozed'),
          ),
        );
    await AlarmRepository(db).cancelForHabitDay('h9', '2026-01-02');
    final gone = await (db.select(
      db.alarmsIndex,
    )..where((r) => r.id.equals('snoozed-habit'))).getSingleOrNull();
    expect(gone, null);
  });

  test('stale fired rows are removed and release their request code', () async {
    final db = _db();
    addTearDown(db.close);
    const firedId = 'stale-ring';
    await db
        .into(db.alarmsIndex)
        .insert(
          AlarmsIndexCompanion.insert(
            id: firedId,
            sourceType: 'task_reminder',
            sourceId: 'old#r0',
            fireAtUtc:
                DateTime.now().toUtc().millisecondsSinceEpoch -
                25 * 60 * 60 * 1000,
            requestCode: const Value(100000),
            state: const Value('fired'),
            kind: const Value('reminder'),
            preset: const Value('notification'),
          ),
        );
    await TaskRepository(
      db,
    ).createTask(title: 'Tomorrow', dueDate: _tomorrowKey(), dueTime: 23 * 60);
    final planned = await AlarmRepository(db)
        .rebuildWindow(dueTomorrowEnabled: false);
    expect(planned, 1);
    final stale = await (db.select(
      db.alarmsIndex,
    )..where((a) => a.id.equals(firedId))).getSingleOrNull();
    expect(stale, null);
    final scheduled = await (db.select(
      db.alarmsIndex,
    )..where((a) => a.state.equals('scheduled'))).get();
    expect(scheduled.map((r) => r.requestCode), [100000]);
  });

  test('byRequestCode returns the matching alarm row', () async {
    final db = _db();
    addTearDown(db.close);
    await db
        .into(db.alarmsIndex)
        .insert(
          AlarmsIndexCompanion.insert(
            id: 'ring1',
            sourceType: 'event',
            sourceId: 'e1',
            fireAtUtc: DateTime.now().toUtc().millisecondsSinceEpoch,
            requestCode: const Value(4242),
            state: const Value('fired'),
            title: const Value('Ring me'),
          ),
        );
    final repo = AlarmRepository(db);
    final row = await repo.byRequestCode(4242);
    expect(row?.title, 'Ring me');
    expect(await repo.byRequestCode(9999), null);
  });

  test('task occurrence-cache rows do not produce event candidates', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.occurrenceCache)
        .insert(
          OccurrenceCacheCompanion.insert(
            id: 'oc1',
            eventId: 't1',
            startUtc: now + 3600000,
            endUtc: now + 7200000,
            dayKey: _tomorrowKey(),
            sourceType: const Value('task'),
          ),
        );
    await AlarmRepository(db).rebuildWindow();
    final rows =
        await (db.select(db.alarmsIndex)..where(
              (a) =>
                  a.sourceType.equals('event_reminder') |
                  a.sourceType.equals('event'),
            ))
            .get();
    expect(rows, isEmpty);
  });

  Future<String> seedEventSeries(
    AppDatabase db, {
    required DateTime start,
    String reminders = '[60]',
    String alarmPreset = 'full_short',
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.calendars)
        .insert(
          CalendarsCompanion.insert(
            id: 'cal1',
            name: 'c',
            createdAt: now,
            updatedAt: now,
          ),
        );
    return EventRepository(db, OccurrenceRepository(db)).createEvent(
      calendarId: 'cal1',
      title: 'Series',
      startUtc: start,
      endUtc: start.add(const Duration(hours: 1)),
      tzId: 'UTC',
      rrule: 'FREQ=DAILY;COUNT=3',
      reminders: reminders,
      alarmPreset: alarmPreset,
    );
  }

  test('event exception uses its own reminders and alarm preset', () async {
    final db = _db();
    addTearDown(db.close);
    final start = DateTime.now().toUtc().add(const Duration(hours: 2));
    final master = await seedEventSeries(db, start: start);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final second = start.add(const Duration(days: 1));
    await repo.editOccurrence(
      master,
      second,
      scope: EditScope.single,
      reminders: () => '[5]',
      alarmPreset: () => 'notification',
    );
    await OccurrenceRepository(db).rebuildWindow(
      windowStartUtc: start.subtract(const Duration(days: 1)),
      windowEndUtc: start.add(const Duration(days: 4)),
    );
    await AlarmRepository(db).rebuildWindow(dueTomorrowEnabled: false);

    final prefix = '$master@${second.millisecondsSinceEpoch}';
    final rows = await (db.select(
      db.alarmsIndex,
    )..where((a) => a.sourceId.like('$prefix%'))).get();
    final reminders = rows.where((r) => r.kind == 'reminder').toList();
    final alarms = rows.where((r) => r.kind == 'alarm').toList();
    expect(reminders.map((r) => r.sourceId), ['$prefix#r5']);
    expect(alarms.single.preset, 'notification');
  });

  test(
    'event exception without alerts inherits master reminders and alarm',
    () async {
      final db = _db();
      addTearDown(db.close);
      final start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final master = await seedEventSeries(db, start: start);
      final repo = EventRepository(db, OccurrenceRepository(db));
      final second = start.add(const Duration(days: 1));
      final exId = await repo.editOccurrence(
        master,
        second,
        scope: EditScope.single,
        title: 'Remote exception',
      );
      // Simulate a pulled remote exception with no local alert overrides.
      await (db.update(db.events)..where((e) => e.id.equals(exId))).write(
        const EventsCompanion(reminders: Value(null), alarmPreset: Value(null)),
      );
      await OccurrenceRepository(db).rebuildWindow(
        windowStartUtc: start.subtract(const Duration(days: 1)),
        windowEndUtc: start.add(const Duration(days: 4)),
      );
      await AlarmRepository(db).rebuildWindow(dueTomorrowEnabled: false);

      final prefix = '$master@${second.millisecondsSinceEpoch}';
      final rows = await (db.select(
        db.alarmsIndex,
      )..where((a) => a.sourceId.like('$prefix%'))).get();
      final reminders = rows.where((r) => r.kind == 'reminder').toList();
      final alarms = rows.where((r) => r.kind == 'alarm').toList();
      expect(reminders.map((r) => r.sourceId), ['$prefix#r60']);
      expect(alarms.single.preset, 'full_short');
    },
  );
}
