import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/countdown_repository.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/focus_repository.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/data/repositories/note_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/domain/habits/date_key.dart';
import 'package:ephemeron/features/habits/presentation/habits_screen.dart';
import 'package:ephemeron/features/sync/application/pending_operations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records bulk habit actions without arming the real durable undo timer.
class _RecordingPendingOperations extends PendingOperations {
  // The repositories need the same db instance, so a super parameter cannot
  // be forwarded to the other constructor arguments.
  // ignore: use_super_parameters
  _RecordingPendingOperations(AppDatabase db)
    : super(
        db,
        tasks: TaskRepository(db),
        notes: NoteRepository(db),
        habits: HabitRepository(db),
        countdowns: CountdownRepository(db),
        focus: FocusRepository(db),
        events: EventRepository(db, OccurrenceRepository(db)),
      );

  final Map<String, bool> archiveCalls = {};
  final List<String> deleteCalls = [];
  final List<String> cancelledIds = [];

  @override
  Future<String> scheduleHabitArchive(String id, bool archived) async {
    archiveCalls[id] = archived;
    return 'archive:$id';
  }

  @override
  Future<String> scheduleHabitDelete(String id) async {
    deleteCalls.add(id);
    return 'delete:$id';
  }

  @override
  Future<void> cancel(String id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAll(Iterable<String> ids) async {
    cancelledIds.addAll(ids);
  }
}

/// The row's semantics node mirrors the leading ring's fully-done state.
bool? _habitRowDone(WidgetTester tester, String name) => tester
    .widget<Semantics>(
      find.bySemanticsLabel(RegExp('^${RegExp.escape(name)},')),
    )
    .properties
    .toggled;

void main() {
  testWidgets('row taps count steps toward the goal, not full completion', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final id = await repo.createHabit(
      name: 'Water',
      startDate: '2026-01-01',
      goalAmount: 3,
      increment: 1,
    );
    final today = habitDateKey(DateTime.now());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Water'));
    await tester.pump();
    await tester.pump();
    var log = await repo.logFor(id, today);
    expect(log?.amount, 1);
    expect(log?.done, isFalse);
    expect(_habitRowDone(tester, 'Water'), isFalse);

    await tester.tap(find.text('Water'));
    await tester.pump();
    await tester.pump();
    log = await repo.logFor(id, today);
    expect(log?.amount, 2);
    expect(log?.done, isFalse);
    expect(_habitRowDone(tester, 'Water'), isFalse);

    await tester.tap(find.text('Water'));
    await tester.pump();
    await tester.pump();
    log = await repo.logFor(id, today);
    expect(log?.amount, 3);
    expect(log?.done, isTrue);
    expect(_habitRowDone(tester, 'Water'), isTrue);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('row taps to goal clear a prior skip', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final id = await repo.createHabit(
      name: 'Water',
      startDate: '2026-01-01',
      goalAmount: 3,
      increment: 1,
    );
    final today = habitDateKey(DateTime.now());
    // Reaching the goal through row taps must not leave a day both done and
    // skipped: setDone cleared skip before row taps started advancing.
    await repo.setSkipped(id, today, true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Partial progress keeps the skip intact; only completion clears it.
    await tester.tap(find.text('Water'));
    await tester.pump();
    await tester.pump();
    var log = await repo.logFor(id, today);
    expect(log?.amount, 1);
    expect(log?.done, isFalse);
    expect(log?.skipped, isTrue);

    await tester.tap(find.text('Water'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Water'));
    await tester.pump();
    await tester.pump();
    log = await repo.logFor(id, today);
    expect(log?.amount, 3);
    expect(log?.done, isTrue);
    expect(log?.skipped, isFalse);
    expect(_habitRowDone(tester, 'Water'), isTrue);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('leading circle marks fully done through the shared toggle API', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final id = await repo.createHabit(
      name: 'Walk',
      startDate: '2026-01-01',
      goalAmount: 5,
      increment: 1,
    );
    final today = habitDateKey(DateTime.now());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final circle = find.byKey(ValueKey<String>('habit-done-$id'));
    expect(circle, findsOneWidget);

    // A row tap only advances progress; the ring stays unfilled and unchecked.
    await tester.tap(find.text('Walk'));
    await tester.pump();
    await tester.pump();
    var log = await repo.logFor(id, today);
    expect(log?.amount, 1);
    expect(log?.done, isFalse);
    expect(_habitRowDone(tester, 'Walk'), isFalse);

    // Only the leading circle marks the day fully done, filling the goal as
    // the Today strip's shared toggle does.
    await tester.tap(circle);
    await tester.pump();
    await tester.pump();
    log = await repo.logFor(id, today);
    expect(log?.amount, 5);
    expect(log?.done, isTrue);
    expect(_habitRowDone(tester, 'Walk'), isTrue);

    await tester.tap(circle);
    await tester.pump();
    await tester.pump();
    log = await repo.logFor(id, today);
    expect(log?.done, isFalse);
    expect(log?.amount, 0);
    expect(_habitRowDone(tester, 'Walk'), isFalse);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('long-press on row marks habit complete without adding a step', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final id = await repo.createHabit(
      name: 'Meditate',
      startDate: '2026-01-01',
      goalAmount: 5,
      increment: 1,
    );
    final today = habitDateKey(DateTime.now());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.longPress(find.text('Meditate'));
    await tester.pump();
    await tester.pump();

    final log = await repo.logFor(id, today);
    expect(log?.done, isTrue);
    expect(log?.amount, 5);
    expect(_habitRowDone(tester, 'Meditate'), isTrue);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('row taps add the configured increment per tap', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final id = await repo.createHabit(
      name: 'Run',
      startDate: '2026-01-01',
      goalAmount: 10,
      unit: 'min',
      increment: 2,
    );
    final today = habitDateKey(DateTime.now());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Run'));
    await tester.pump();
    await tester.pump();
    expect((await repo.logFor(id, today))?.amount, 2);
    expect(find.textContaining('2/10 min'), findsOneWidget);

    await tester.tap(find.text('Run'));
    await tester.pump();
    await tester.pump();
    expect((await repo.logFor(id, today))?.amount, 4);
    expect(find.textContaining('4/10 min'), findsOneWidget);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('habit complete writes today log', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final id = await repo.createHabit(name: 'Read', startDate: '2026-01-01');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Read'), findsOneWidget);
    await tester.tap(find.text('Read'));
    await tester.pump();
    await tester.pump();
    final today = habitDateKey(DateTime.now());
    expect((await repo.logFor(id, today))?.done, isTrue);
    // Close the db and unmount inside the test body so Drift's
    // stream-close timer fires before the pending-timer check.
    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('habit row shows live progress from a linked focus session', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final id = await repo.createHabit(
      name: 'Run',
      startDate: '2026-01-01',
      goalAmount: 10,
      unit: 'min',
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'f1',
            habitId: Value(id),
            startUtc: now - 5 * 60000,
            targetEndUtc: Value(now + 20 * 60000),
            phase: const Value('focus'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Run'), findsOneWidget);
    final live = find.textContaining(RegExp(r'\d+\.\d%'));
    expect(live, findsOneWidget);
    final liveText = tester.widget<Text>(live).data!;
    final pct = double.parse(
      RegExp(r'(\d+\.\d)%').firstMatch(liveText)!.group(1)!,
    );
    expect(pct, greaterThanOrEqualTo(50.0));
    expect(pct, lessThan(52.0));
    // Close the db and unmount inside the test body so Drift's
    // stream-close timer fires before the pending-timer check.
    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('break session does not add live habit progress', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final id = await repo.createHabit(
      name: 'Run',
      startDate: '2026-01-01',
      goalAmount: 10,
      unit: 'min',
    );
    final today = habitDateKey(DateTime.now());
    await repo.addAmount(id, today, 2);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'f2',
            habitId: Value(id),
            startUtc: now - 5 * 60000,
            targetEndUtc: Value(now + 5 * 60000),
            phase: const Value('break'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('2/10 min'), findsOneWidget);
    expect(find.textContaining('70.0%'), findsNothing);
    // Close the db and unmount inside the test body so Drift's
    // stream-close timer fires before the pending-timer check.
    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('habit row minus control decrements the amount', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final id = await repo.createHabit(
      name: 'Run',
      startDate: '2026-01-01',
      goalAmount: 10,
      unit: 'min',
      increment: 2,
    );
    final today = habitDateKey(DateTime.now());
    await repo.addAmount(id, today, 5);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subtract 2'));
    await tester.pumpAndSettle();
    expect((await repo.logFor(id, today))?.amount, 3);
    // Close the db and unmount inside the test body so Drift's
    // stream-close timer fires before the pending-timer check.
    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets(
    'menu select enters selection and archive schedules a pending op',
    (WidgetTester tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = HabitRepository(db);
      final pendingOps = _RecordingPendingOperations(db);
      final id = await repo.createHabit(name: 'Read', startDate: '2026-01-01');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            pendingOperationsProvider.overrideWithValue(pendingOps),
          ],
          child: const MaterialApp(home: HabitsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select').last);
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byTooltip('Archive'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);
      await tester.tap(find.byTooltip('Archive'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(pendingOps.archiveCalls, {id: true});
      expect(find.text('1 selected'), findsNothing);
      // Close the db and unmount inside the test body so Drift's
      // stream-close timer fires before the pending-timer check.
      await db.close();
      await tester.pumpWidget(Container());
      await tester.pump();
    },
  );

  testWidgets('selection prunes rows that leave the active list', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final pendingOps = _RecordingPendingOperations(db);
    final id = await repo.createHabit(name: 'Read', startDate: '2026-01-01');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pendingOperationsProvider.overrideWithValue(pendingOps),
        ],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select').last);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    // Read leaves the active (unarchived) list while selected.
    await repo.archiveHabit(id, true);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('selected'), findsNothing);
    expect(find.text('Habits'), findsOneWidget);
    expect(pendingOps.archiveCalls, isEmpty);
    // Unmount first so the per-habit providers dispose, then let Drift's
    // stream-close work settle before closing the in-memory database.
    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  });

  testWidgets('bulk archive resolves the live selected rows', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final pendingOps = _RecordingPendingOperations(db);
    final readId = await repo.createHabit(
      name: 'Read',
      startDate: '2026-01-01',
    );
    final runId = await repo.createHabit(name: 'Run', startDate: '2026-01-01');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pendingOperationsProvider.overrideWithValue(pendingOps),
        ],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('More options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select').last);
    await tester.pump();
    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    // Run leaves the active list while both rows are selected.
    await repo.archiveHabit(runId, true);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Archive'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(pendingOps.archiveCalls, {readId: true});
    expect(pendingOps.archiveCalls.containsKey(runId), isFalse);
    expect(find.textContaining('selected'), findsNothing);
    // Unmount first so the per-habit providers dispose, then let Drift's
    // stream-close work settle before closing the in-memory database.
    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  });

  testWidgets('delete action requires confirmation and schedules deletes', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final pendingOps = _RecordingPendingOperations(db);
    final id = await repo.createHabit(name: 'Read', startDate: '2026-01-01');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pendingOperationsProvider.overrideWithValue(pendingOps),
        ],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select').last);
    await tester.pump();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Delete 1 habit?'), findsOneWidget);
    expect(pendingOps.deleteCalls, isEmpty);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(pendingOps.deleteCalls, [id]);
    expect(find.text('1 selected'), findsNothing);
    // Close the db and unmount inside the test body so Drift's
    // stream-close timer fires before the pending-timer check.
    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });
}
