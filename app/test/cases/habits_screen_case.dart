import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/domain/habits/date_key.dart';
import 'package:ephemeron/features/habits/presentation/habits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.byType(Checkbox), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
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
    final tile = find.ancestor(
      of: find.text('Run'),
      matching: find.byType(ListTile),
    );
    final live = find.descendant(
      of: tile,
      matching: find.textContaining(RegExp(r'\d+\.\d%')),
    );
    expect(live, findsOneWidget);
    final liveText = tester.widget<Text>(live).data!;
    final pct = double.parse(
      RegExp(r'^(\d+\.\d)%').firstMatch(liveText)!.group(1)!,
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
}
