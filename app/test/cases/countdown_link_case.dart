// Linked countdowns: create/link, watch by entity, unlink, date sync,
// unknown-type rejection, backup round-trip, and the entity section widget.
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/time/time.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/countdown_repository.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/countdowns/presentation/entity_countdown_section.dart';
import 'package:ephemeron/features/settings/data/backup_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_fixtures.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<Countdown> _row(AppDatabase db, String id) {
  return (db.select(db.countdowns)..where((c) => c.id.equals(id))).getSingle();
}

void main() {
  test('create stores a link and watchLinkedCountdowns finds it', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = CountdownRepository(db);
    final id = await repo.createCountdown(
      title: 'Trip',
      targetDate: '2027-06-01',
      linkedType: 'event',
      linkedId: 'ev1',
    );
    final row = await _row(db, id);
    expect(row.linkedType, 'event');
    expect(row.linkedId, 'ev1');

    final linked = await repo.watchLinkedCountdowns('event', 'ev1').first;
    expect(linked.map((c) => c.id), [id]);
    expect(await repo.watchLinkedCountdowns('event', 'other').first, isEmpty);

    // Other entity kinds with the same id do not leak into the result.
    await repo.createCountdown(
      title: 'Habit streak',
      linkedType: 'habit',
      linkedId: 'ev1',
    );
    expect(
      (await repo.watchLinkedCountdowns('event', 'ev1').first),
      hasLength(1),
    );
  });

  test('unknown link types and empty ids degrade to unlinked', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = CountdownRepository(db);

    final unknown = await repo.createCountdown(
      title: 'Unknown',
      linkedType: 'note',
      linkedId: 'n1',
    );
    final emptyId = await repo.createCountdown(
      title: 'Empty',
      linkedType: 'task',
      linkedId: '   ',
    );
    final valid = await repo.createCountdown(
      title: 'Valid',
      linkedType: 'habit',
      linkedId: 'h1',
    );

    for (final id in [unknown, emptyId]) {
      final row = await _row(db, id);
      expect(row.linkedType, isNull);
      expect(row.linkedId, isNull);
    }
    final habit = await _row(db, valid);
    expect(habit.linkedType, 'habit');
    expect(habit.linkedId, 'h1');

    // An unknown type supplied by an update clears the pair instead of
    // persisting an unusable link.
    await repo.updateCountdown(
      valid,
      linkedType: () => 'calendar',
      linkedId: () => 'cal1',
    );
    final cleared = await _row(db, valid);
    expect(cleared.linkedType, isNull);
    expect(cleared.linkedId, isNull);
  });

  test('editing content preserves the link; unlink paths clear it', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = CountdownRepository(db);
    final preserved = await repo.createCountdown(
      title: 'Preserved',
      linkedType: 'task',
      linkedId: 't1',
    );
    final viaUpdate = await repo.createCountdown(
      title: 'Via update',
      linkedType: 'task',
      linkedId: 't1',
    );
    final viaClear = await repo.createCountdown(
      title: 'Via clear',
      linkedType: 'event',
      linkedId: 'e1',
    );

    await repo.updateCountdown(preserved, title: 'Renamed');
    var row = await _row(db, preserved);
    expect(row.title, 'Renamed');
    expect(row.linkedType, 'task');
    expect(row.linkedId, 't1');

    await repo.updateCountdown(
      viaUpdate,
      linkedType: () => null,
      linkedId: () => null,
    );
    row = await _row(db, viaUpdate);
    expect(row.linkedType, isNull);
    expect(row.linkedId, isNull);

    await repo.clearLink(viaClear);
    row = await _row(db, viaClear);
    expect(row.linkedType, isNull);
    expect(row.linkedId, isNull);
  });

  test('syncLinkedTargetDate updates live rows and ignores null', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = CountdownRepository(db);
    final first = await repo.createCountdown(
      title: 'First',
      targetDate: '2027-01-01',
      linkedType: 'event',
      linkedId: 'ev1',
    );
    final second = await repo.createCountdown(
      title: 'Second',
      targetDate: null,
      linkedType: 'event',
      linkedId: 'ev1',
    );
    final unrelated = await repo.createCountdown(
      title: 'Unrelated',
      targetDate: '2027-02-02',
      linkedType: 'event',
      linkedId: 'ev2',
    );
    final deleted = await repo.createCountdown(
      title: 'Deleted',
      targetDate: '2027-03-03',
      linkedType: 'event',
      linkedId: 'ev1',
    );
    await repo.deleteCountdown(deleted);

    await repo.syncLinkedTargetDate('event', 'ev1', '2028-09-09');
    expect((await _row(db, first)).targetDate, '2028-09-09');
    expect((await _row(db, second)).targetDate, '2028-09-09');
    expect((await _row(db, unrelated)).targetDate, '2027-02-02');
    expect((await _row(db, deleted)).targetDate, '2027-03-03');

    await repo.syncLinkedTargetDate('event', 'ev1', null);
    expect((await _row(db, first)).targetDate, '2028-09-09');
    await repo.syncLinkedTargetDate('bogus', 'ev1', '2029-01-01');
    expect((await _row(db, first)).targetDate, '2028-09-09');
  });

  test('syncLinkedTargetDate updates only rows whose date changed', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = CountdownRepository(db);
    final matching = await repo.createCountdown(
      title: 'Matching',
      targetDate: '2028-09-09',
      linkedType: 'event',
      linkedId: 'ev3',
    );
    final differing = await repo.createCountdown(
      title: 'Differing',
      targetDate: '2027-01-01',
      linkedType: 'event',
      linkedId: 'ev3',
    );
    await db.customStatement(
      'UPDATE countdowns SET updated_at = 123 WHERE id = ?',
      [matching],
    );

    await repo.syncLinkedTargetDate('event', 'ev3', '2028-09-09');
    var matchingRow = await _row(db, matching);
    var differingRow = await _row(db, differing);
    expect(matchingRow.updatedAt, 123);
    expect(differingRow.targetDate, '2028-09-09');
    expect(differingRow.updatedAt, isNot(123));

    // A second identical call has nothing to change, so updatedAt stays put.
    final changedAt = differingRow.updatedAt;
    await repo.syncLinkedTargetDate('event', 'ev3', '2028-09-09');
    matchingRow = await _row(db, matching);
    differingRow = await _row(db, differing);
    expect(matchingRow.updatedAt, 123);
    expect(differingRow.updatedAt, changedAt);
  });

  test('task due-date updates keep a linked countdown in step', () async {
    final db = _db();
    addTearDown(db.close);
    final tasks = TaskRepository(db);
    final countdowns = CountdownRepository(db);
    final taskId = await tasks.createTask(title: 'Ship', dueDate: '2026-05-01');
    final countdownId = await countdowns.createCountdown(
      title: 'Ship day',
      targetDate: '2026-05-01',
      linkedType: 'task',
      linkedId: taskId,
    );

    await tasks.updateTask(taskId, dueDate: () => '2026-05-02');
    expect((await _row(db, countdownId)).targetDate, '2026-05-02');

    // A custom countdown date survives an edit that re-sends the same due date.
    await countdowns.updateCountdown(
      countdownId,
      targetDate: () => '2026-06-01',
    );
    await tasks.updateTask(
      taskId,
      title: 'Renamed',
      dueDate: () => '2026-05-02',
    );
    expect((await _row(db, countdownId)).targetDate, '2026-06-01');

    // Clearing a due date must not wipe the user's countdown date.
    await tasks.updateTask(taskId, dueDate: () => null);
    expect((await _row(db, countdownId)).targetDate, '2026-06-01');
  });

  test('event start-date edits keep a linked countdown in step', () async {
    final db = _db();
    addTearDown(db.close);
    const now = 1700000000000;
    await db
        .into(db.calendars)
        .insert(
          CalendarsCompanion.insert(
            id: 'cal1',
            name: 'Main',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final events = EventRepository(db, OccurrenceRepository(db));
    final countdowns = CountdownRepository(db);
    final start = DateTime.utc(2026, 5, 1, 12);
    final eventId = await events.createEvent(
      calendarId: 'cal1',
      title: 'Launch',
      startUtc: start,
    );
    final expected = dateKey(start.toLocal());
    final countdownId = await countdowns.createCountdown(
      title: 'Launch day',
      targetDate: expected,
      linkedType: 'event',
      linkedId: eventId,
    );

    final next = DateTime.utc(2026, 5, 2, 12);
    await events.editOccurrence(
      eventId,
      start,
      scope: EditScope.all,
      startUtc: next,
    );
    expect((await _row(db, countdownId)).targetDate, dateKey(next.toLocal()));
  });

  test('backup round-trip preserves linked fields', () async {
    final db1 = _db();
    addTearDown(db1.close);
    final repo = CountdownRepository(db1);
    final linkedId = await repo.createCountdown(
      title: 'Linked',
      targetDate: '2027-06-01',
      linkedType: 'habit',
      linkedId: 'h1',
    );
    final unlinkedId = await repo.createCountdown(title: 'Plain');

    final service1 = BackupService(db1);
    final raw = service1.encode(await service1.exportJson());

    final db2 = _db();
    addTearDown(db2.close);
    final service2 = BackupService(db2);
    await service2.restoreJson(service2.decode(raw));

    final linked = await _row(db2, linkedId);
    expect(linked.title, 'Linked');
    expect(linked.linkedType, 'habit');
    expect(linked.linkedId, 'h1');
    final plain = await _row(db2, unlinkedId);
    expect(plain.linkedType, isNull);
    expect(plain.linkedId, isNull);
  });

  test(
    'restore rejects unusable countdown links from untrusted backup',
    () async {
      final db = _db();
      addTearDown(db.close);
      final service = BackupService(db);
      await service.restoreJson({
        'version': 1,
        'tables': {
          'countdowns': [
            {
              'id': 'bad-type',
              'title': 'Bad type',
              'yearlyRepeat': false,
              'showAge': false,
              'linkedType': 'note',
              'linkedId': 'n1',
              'createdAt': 1,
              'updatedAt': 2,
            },
            {
              'id': 'empty-id',
              'title': 'Empty id',
              'yearlyRepeat': false,
              'showAge': false,
              'linkedType': 'task',
              'linkedId': '',
              'createdAt': 1,
              'updatedAt': 2,
            },
            // Older backups may omit the link keys entirely.
            {
              'id': 'legacy',
              'title': 'Legacy',
              'yearlyRepeat': false,
              'showAge': false,
              'createdAt': 1,
              'updatedAt': 2,
            },
          ],
        },
      });

      for (final id in const ['bad-type', 'empty-id', 'legacy']) {
        final row = await _row(db, id);
        expect(row.linkedType, isNull, reason: id);
        expect(row.linkedId, isNull, reason: id);
      }
    },
  );

  testWidgets('entity section shows linked countdowns and opens editor', (
    WidgetTester tester,
  ) async {
    final db = _db();
    final repo = CountdownRepository(db);
    await repo.createCountdown(
      title: 'Linked trip',
      targetDate: '2027-06-01',
      linkedType: 'event',
      linkedId: 'ev1',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: EntityCountdownSection(
              linkedType: 'event',
              linkedId: 'ev1',
              initialTitle: 'Launch party',
              initialDate: DateTime(2027, 6, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Countdown'), findsOneWidget);
    expect(find.text('Linked trip'), findsOneWidget);
    expect(find.text('Add countdown'), findsOneWidget);

    await tester.tap(find.text('Add countdown'));
    await settle(tester);
    expect(find.text('New countdown'), findsOneWidget);
    expect(find.text('Launch party'), findsOneWidget);
    expect(find.text('Linked to Event'), findsOneWidget);

    Navigator.of(tester.element(find.text('New countdown'))).pop();
    await settle(tester);
    // Close the db and unmount inside the test body so Drift's stream-close
    // timer fires before the pending-timer check.
    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });
}
