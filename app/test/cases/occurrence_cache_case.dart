import 'package:drift/drift.dart' hide isNull;
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fixtures.dart';

Future<void> _cal(
  AppDatabase db, {
  String id = 'cal1',
  String name = 'c',
  String source = 'device',
  String? googleAccount,
  String? microsoftAccount,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: id,
          name: name,
          source: Value(source),
          googleAccount: Value(googleAccount),
          microsoftAccount: Value(microsoftAccount),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _taskList(
  AppDatabase db, {
  required String id,
  required String name,
  String? googleAccount,
  String? microsoftAccount,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.taskLists)
      .insert(
        TaskListsCompanion.insert(
          id: id,
          name: name,
          googleAccount: Value(googleAccount),
          microsoftAccount: Value(microsoftAccount),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _event(
  AppDatabase db, {
  required String id,
  String calendarId = 'cal1',
  String? rrule,
  String? masterId,
  int? originalStart,
  String status = 'confirmed',
  int? startUtc,
  int? endUtc,
  String? tzId,
  String? startDate,
  String? endDate,
  bool isAllDay = false,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: id,
          calendarId: calendarId,
          createdAt: now,
          updatedAt: now,
          startUtc: Value(startUtc),
          endUtc: Value(endUtc),
          startDate: Value(startDate),
          endDate: Value(endDate),
          isAllDay: Value(isAllDay),
          rrule: Value(rrule),
          recurringMasterId: Value(masterId),
          originalStart: Value(originalStart),
          status: Value(status),
          tzId: Value(tzId),
        ),
      );
}

late AppDatabase db;

void main() {
  setUpAll(() async {
    db = newTestDb();
  });
  tearDownAll(() async {});
  setUp(() async {
    await resetTestDb(db);
  });
  test('rebuild expands a daily master into the window only', () async {
    await _cal(db);
    final start = DateTime.utc(2026, 3, 2, 9);
    await _event(
      db,
      id: 'm1',
      rrule: 'FREQ=DAILY;COUNT=10',
      startUtc: start.millisecondsSinceEpoch,
      endUtc: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      tzId: 'UTC',
    );
    final repo = OccurrenceRepository(db);
    final n = await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 5, 23, 59),
    );
    expect(n, 4);
    final rows = await repo.occurrencesForDay('2026-03-03');
    expect(rows.length, 1);
    expect(rows.single.eventId, 'm1');
  });

  test('cancelled exception removes that occurrence', () async {
    await _cal(db);
    final start = DateTime.utc(2026, 3, 2, 9);
    await _event(
      db,
      id: 'm1',
      rrule: 'FREQ=DAILY;COUNT=5',
      startUtc: start.millisecondsSinceEpoch,
      endUtc: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      tzId: 'UTC',
    );
    await _event(
      db,
      id: 'ex1',
      masterId: 'm1',
      originalStart: DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch,
      status: 'cancelled',
    );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 8),
    );
    expect(await repo.occurrencesForDay('2026-03-03'), isEmpty);
    expect((await repo.occurrencesForDay('2026-03-04')).length, 1);
  });

  test('all-day exclusive end spans only the covered days', () async {
    await _cal(db);
    await _event(
      db,
      id: 'single',
      startDate: '2026-11-03',
      endDate: '2026-11-04',
      isAllDay: true,
    );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 11, 1),
      windowEndUtc: DateTime.utc(2026, 11, 30),
    );
    expect((await repo.occurrencesForDay('2026-11-03')).length, 1);
    expect(await repo.occurrencesForDay('2026-11-04'), isEmpty);
  });

  test('all-day multi-day exclusive end excludes the end date', () async {
    await _cal(db);
    await _event(
      db,
      id: 'multi',
      startDate: '2026-11-03',
      endDate: '2026-11-06',
      isAllDay: true,
    );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 11, 1),
      windowEndUtc: DateTime.utc(2026, 11, 30),
    );
    for (final day in ['2026-11-03', '2026-11-04', '2026-11-05']) {
      expect((await repo.occurrencesForDay(day)).length, 1);
    }
    expect(await repo.occurrencesForDay('2026-11-06'), isEmpty);
  });

  test('legacy all-day row with end==start stays one day', () async {
    await _cal(db);
    await _event(
      db,
      id: 'legacy',
      startDate: '2026-11-03',
      endDate: '2026-11-03',
      isAllDay: true,
    );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 11, 1),
      windowEndUtc: DateTime.utc(2026, 11, 30),
    );
    expect((await repo.occurrencesForDay('2026-11-03')).length, 1);
    expect(await repo.occurrencesForDay('2026-11-04'), isEmpty);
  });

  test('task occurrences use planned date as all-day when set', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: 't1',
            title: const Value('Plan'),
            dueDate: const Value('2026-03-10'),
            plannedDate: const Value('2026-03-05'),
            dueTime: const Value(540),
            durationMin: const Value(60),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 31),
    );
    final rows = await repo.occurrencesForDay('2026-03-05');
    expect(rows, hasLength(1));
    expect(rows.single.eventId, 't1');
    expect(
      rows.single.startUtc,
      DateTime(2026, 3, 5).toUtc().millisecondsSinceEpoch,
    );
    expect(await repo.occurrencesForDay('2026-03-10'), isEmpty);
  });

  test('task occurrences fall back to timed due date when unplanned', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: 't2',
            title: const Value('Due only'),
            dueDate: const Value('2026-03-06'),
            dueTime: const Value(540),
            durationMin: const Value(60),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 31),
    );
    final rows = await repo.occurrencesForDay('2026-03-06');
    expect(rows, hasLength(1));
    expect(
      rows.single.startUtc,
      DateTime(2026, 3, 6, 9).toUtc().millisecondsSinceEpoch,
    );
    expect(
      rows.single.endUtc,
      DateTime(2026, 3, 6, 10).toUtc().millisecondsSinceEpoch,
    );
  });

  test('invalidateEvent clears rows for master and exceptions', () async {
    await _cal(db);
    final start = DateTime.utc(2026, 3, 2, 9);
    await _event(
      db,
      id: 'm1',
      rrule: 'FREQ=DAILY;COUNT=5',
      startUtc: start.millisecondsSinceEpoch,
      endUtc: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      tzId: 'UTC',
    );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 8),
    );
    await repo.invalidateEvent('m1');
    expect(await repo.occurrencesForDay('2026-03-04'), isEmpty);
  });

  test(
    'non-recurring plannedStart/plannedEnd becomes timed task block',
    () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 't1',
              title: const Value('Timed'),
              plannedStart: const Value('2026-03-05T09:00'),
              plannedEnd: const Value('2026-03-05T10:00'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final repo = OccurrenceRepository(db);
      await repo.rebuildWindow(
        windowStartUtc: DateTime.utc(2026, 3, 1),
        windowEndUtc: DateTime.utc(2026, 3, 31),
      );
      final rows = await db.select(db.occurrenceCache).get();
      expect(rows, hasLength(1));
      expect(rows.single.sourceType, 'task');
      expect(
        rows.single.startUtc,
        DateTime(2026, 3, 5, 9).toUtc().millisecondsSinceEpoch,
      );
      expect(
        rows.single.endUtc,
        DateTime(2026, 3, 5, 10).toUtc().millisecondsSinceEpoch,
      );
    },
  );

  test(
    'recurring open task projects future and skips completed sibling',
    () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'master',
              title: const Value('Recur'),
              plannedStart: const Value('2026-03-02T09:00'),
              plannedEnd: const Value('2026-03-02T10:00'),
              rrule: const Value('FREQ=DAILY;COUNT=3'),
              seriesId: const Value('s1'),
              recurrenceKey: const Value('2026-03-02'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      // completed sibling occurrence for 2026-03-03
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'sib',
              title: const Value('Recur'),
              plannedStart: const Value('2026-03-03T09:00'),
              plannedEnd: const Value('2026-03-03T10:00'),
              rrule: const Value('FREQ=DAILY;COUNT=3'),
              seriesId: const Value('s1'),
              recurrenceKey: const Value('2026-03-03'),
              completedAt: Value(now),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final repo = OccurrenceRepository(db);
      await repo.rebuildWindow(
        windowStartUtc: DateTime.utc(2026, 3, 1),
        windowEndUtc: DateTime.utc(2026, 3, 10),
      );
      final days = [
        for (final r in await db.select(db.occurrenceCache).get()) r.dayKey,
      ];
      expect(days, contains('2026-03-02'));
      expect(days, isNot(contains('2026-03-03')));
    },
  );

  test('event cache rows sourceType event, task rows task', () async {
    await _cal(db);
    final start = DateTime.utc(2026, 3, 2, 9);
    await _event(
      db,
      id: 'e1',
      startUtc: start.millisecondsSinceEpoch,
      endUtc: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      tzId: 'UTC',
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: 't1',
            title: const Value('Task'),
            plannedDate: const Value('2026-03-02'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 5),
    );
    final rows = await db.select(db.occurrenceCache).get();
    final byEvent = rows.firstWhere((r) => r.eventId == 'e1');
    final byTask = rows.firstWhere((r) => r.eventId == 't1');
    expect(byEvent.sourceType, 'event');
    expect(byTask.sourceType, 'task');
  });

  test('rebuild labels Google, Microsoft and local sources', () async {
    await _cal(
      db,
      id: 'gcal',
      name: 'Work',
      source: 'google',
      googleAccount: 'g@example.com',
    );
    await _cal(
      db,
      id: 'mcal',
      name: 'Outlook',
      source: 'microsoft',
      microsoftAccount: 'm@example.com',
    );
    await _cal(db, id: 'lcal', name: 'On device');
    await _taskList(
      db,
      id: 'glist',
      name: 'Errands',
      googleAccount: 'gt@example.com',
    );
    await _taskList(
      db,
      id: 'mlist',
      name: 'MS Tasks',
      microsoftAccount: 'mt@example.com',
    );

    final day = DateTime.utc(2026, 3, 2, 9);
    for (final (id, calendarId) in [
      ('ge', 'gcal'),
      ('me', 'mcal'),
      ('le', 'lcal'),
    ]) {
      await _event(
        db,
        id: id,
        calendarId: calendarId,
        startUtc: day.millisecondsSinceEpoch,
        endUtc: day.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        tzId: 'UTC',
      );
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final (id, listId) in [('gt', 'glist'), ('mt', 'mlist')]) {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: id,
              listId: Value(listId),
              title: Value(id),
              plannedDate: const Value('2026-03-02'),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 5),
    );
    final rows = await db.select(db.occurrenceCache).get();
    final byId = {for (final row in rows) row.eventId: row};
    expect(byId['ge']!.sourceLabel, 'Work - g@example.com');
    expect(byId['ge']!.sourceAccount, 'g@example.com');
    expect(byId['me']!.sourceLabel, 'Outlook - m@example.com');
    expect(byId['me']!.sourceAccount, 'm@example.com');
    expect(byId['le']!.sourceLabel, 'On device - On this device');
    expect(byId['le']!.sourceAccount, isNull);
    expect(byId['gt']!.sourceLabel, 'Errands - gt@example.com');
    expect(byId['gt']!.sourceAccount, 'gt@example.com');
    expect(byId['mt']!.sourceLabel, 'MS Tasks - mt@example.com');
    expect(byId['mt']!.sourceAccount, 'mt@example.com');
  });

  test('rebuild leaves unresolved source labels null', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: 't1',
            title: const Value('No list'),
            plannedDate: const Value('2026-03-02'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 5),
    );
    final row = (await repo.occurrencesForDay('2026-03-02')).single;
    expect(row.sourceLabel, isNull);
    expect(row.sourceAccount, isNull);
  });

  test(
    'projected recurring occurrence suppressed by per-occurrence state',
    () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'master',
              title: const Value('Recur'),
              plannedStart: const Value('2026-03-02T09:00'),
              plannedEnd: const Value('2026-03-02T10:00'),
              rrule: const Value('FREQ=DAILY;COUNT=3'),
              seriesId: const Value('s1'),
              recurrenceKey: const Value('2026-03-02'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final repo = OccurrenceRepository(db);
      await repo.rebuildWindow(
        windowStartUtc: DateTime.utc(2026, 3, 1),
        windowEndUtc: DateTime.utc(2026, 3, 10),
      );
      expect((await repo.occurrencesForDay('2026-03-03')).length, 1);

      await db
          .into(db.taskOccurrenceStates)
          .insert(
            TaskOccurrenceStatesCompanion.insert(
              seriesId: 's1',
              occurrenceDate: '2026-03-03',
              status: 'completed',
              updatedAt: now,
            ),
          );
      expect(await repo.occurrencesForDay('2026-03-03'), isEmpty);
      expect((await repo.occurrencesForDay('2026-03-02')).length, 1);

      await (db.delete(db.taskOccurrenceStates)..where(
            (s) =>
                s.seriesId.equals('s1') & s.occurrenceDate.equals('2026-03-03'),
          ))
          .go();
      expect((await repo.occurrencesForDay('2026-03-03')).length, 1);
    },
  );

  test('daily all-day recurring series has no duplicate (eventId,startUtc,dayKey) after shifted rebuilds', () async {
    await _cal(db);
    await _event(
      db,
      id: 'm1',
      rrule: 'FREQ=DAILY;COUNT=30',
      startDate: '2026-03-01',
      endDate: '2026-03-02',
      isAllDay: true,
    );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 5),
      windowEndUtc: DateTime.utc(2026, 3, 10),
    );
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 12),
      windowEndUtc: DateTime.utc(2026, 3, 15),
    );
    final rows = await db.select(db.occurrenceCache).get();
    // Each in-window date exactly once.
    final days = rows.map((r) => r.dayKey).toList();
    expect(days.toSet().length, days.length);
  });

  test(
    'multi-day all-day single rebuilt twice keeps one row per covered day',
    () async {
      await _cal(db);
      await _event(
        db,
        id: 'multi',
        startDate: '2026-11-03',
        endDate: '2026-11-06',
        isAllDay: true,
      );
      final repo = OccurrenceRepository(db);
      await repo.rebuildWindow(
        windowStartUtc: DateTime.utc(2026, 11, 1),
        windowEndUtc: DateTime.utc(2026, 11, 30),
      );
      await repo.rebuildWindow(
        windowStartUtc: DateTime.utc(2026, 11, 1),
        windowEndUtc: DateTime.utc(2026, 11, 30),
      );
      for (final day in ['2026-11-03', '2026-11-04', '2026-11-05']) {
        expect((await repo.occurrencesForDay(day)).length, 1);
      }
      expect(await repo.occurrencesForDay('2026-11-06'), isEmpty);
    },
  );

  test('all-day exception moves and suppresses original slot', () async {
    await _cal(db);
    await _event(
      db,
      id: 'm1',
      rrule: 'FREQ=DAILY;COUNT=5',
      startDate: '2026-03-02',
      endDate: '2026-03-03',
      isAllDay: true,
    );
    await _event(
      db,
      id: 'ex1',
      masterId: 'm1',
      originalStart: DateTime.utc(2026, 3, 3).millisecondsSinceEpoch,
      status: 'confirmed',
      startDate: '2026-03-10',
      endDate: '2026-03-11',
      isAllDay: true,
    );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 12),
    );
    expect(await repo.occurrencesForDay('2026-03-03'), isEmpty);
    expect((await repo.occurrencesForDay('2026-03-10')).length, 1);
  });

  test('timed moved exception shows once at new time not original', () async {
    await _cal(db);
    final start = DateTime.utc(2026, 3, 2, 9);
    await _event(
      db,
      id: 'm1',
      rrule: 'FREQ=DAILY;COUNT=5',
      startUtc: start.millisecondsSinceEpoch,
      endUtc: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      tzId: 'UTC',
    );
    final movedStart = DateTime.utc(2026, 3, 4, 11);
    await _event(
      db,
      id: 'ex1',
      masterId: 'm1',
      originalStart: DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch,
      status: 'confirmed',
      startUtc: movedStart.millisecondsSinceEpoch,
      endUtc: movedStart.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      tzId: 'UTC',
    );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 8),
    );
    expect(await repo.occurrencesForDay('2026-03-03'), isEmpty);
    final movedDay = await repo.occurrencesForDay('2026-03-04');
    expect(
      movedDay
          .where((r) => r.startUtc == movedStart.millisecondsSinceEpoch)
          .length,
      1,
    );
  });

  test('timed moved exception outside window not accumulated', () async {
    await _cal(db);
    final start = DateTime.utc(2026, 3, 2, 9);
    await _event(
      db,
      id: 'm1',
      rrule: 'FREQ=DAILY;COUNT=5',
      startUtc: start.millisecondsSinceEpoch,
      endUtc: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      tzId: 'UTC',
    );
    final movedStart = DateTime.utc(2026, 3, 20, 11);
    await _event(
      db,
      id: 'ex1',
      masterId: 'm1',
      originalStart: DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch,
      status: 'confirmed',
      startUtc: movedStart.millisecondsSinceEpoch,
      endUtc: movedStart.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      tzId: 'UTC',
    );
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 5),
      windowEndUtc: DateTime.utc(2026, 3, 10),
    );
    // exception row absent in this window
    final rows1 = await db.select(db.occurrenceCache).get();
    expect(
      rows1
          .where((r) => r.startUtc == movedStart.millisecondsSinceEpoch)
          .length,
      0,
    );
    await repo.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 18),
      windowEndUtc: DateTime.utc(2026, 3, 25),
    );
    final rows2 = await db.select(db.occurrenceCache).get();
    // at most once overall after second rebuild
    expect(
      rows2
          .where((r) => r.startUtc == movedStart.millisecondsSinceEpoch)
          .length,
      lessThanOrEqualTo(1),
    );
  });
}
