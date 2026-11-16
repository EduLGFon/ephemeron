import 'dart:async';

import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/domain/habits/date_key.dart';
import 'package:ephemeron/features/habits/application/habits_providers.dart';
import 'package:ephemeron/features/habits/presentation/habits_stats_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _GatedHabitRepository extends HabitRepository {
  _GatedHabitRepository(super.db, this.gate);

  final Completer<void> gate;
  int addAmountCalls = 0;

  @override
  Future<void> addAmount(String habitId, String dayKey, double amount) async {
    addAmountCalls++;
    await gate.future;
    await super.addAmount(habitId, dayKey, amount);
  }
}

class _ThrowingHabitRepository extends HabitRepository {
  _ThrowingHabitRepository(super.db);

  @override
  Future<void> addAmount(String habitId, String dayKey, double amount) async {
    throw Exception('boom');
  }
}

void main() {
  testWidgets('habit stats screen shows 60% and catch-up action', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final yesterday = habitDateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final id = await repo.createHabit(
      name: 'Read',
      startDate: yesterday,
      goalAmount: 5,
      unit: 'min',
    );
    await repo.addAmount(id, yesterday, 3);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsStatsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Add 2 min'), findsOneWidget);

    await tester.tap(find.text('Add 2 min'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect((await repo.logFor(id, yesterday))?.amount, 5);
    expect((await repo.logFor(id, yesterday))?.done, isTrue);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('habit stats screen is usable at 320dp and 3x text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final yesterday = habitDateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final id = await repo.createHabit(
      name: 'Read',
      startDate: yesterday,
      goalAmount: 5,
      unit: 'min',
    );
    await repo.addAmount(id, yesterday, 3);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
            child: const HabitsStatsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Add 2 min'), findsOneWidget);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('catch-up ignores rapid double tap', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final yesterday = habitDateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final setupRepo = HabitRepository(db);
    final id = await setupRepo.createHabit(
      name: 'Read',
      startDate: yesterday,
      goalAmount: 5,
      unit: 'min',
    );
    await setupRepo.addAmount(id, yesterday, 3);

    final gate = Completer<void>();
    final fake = _GatedHabitRepository(db, gate);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          habitRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: HabitsStatsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Add 2 min'), findsOneWidget);

    await tester.tap(find.text('Add 2 min'));
    await tester.pump();
    await tester.tap(find.text('Add 2 min'), warnIfMissed: false);
    await tester.pump();

    expect(fake.addAmountCalls, 1);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect((await setupRepo.logFor(id, yesterday))?.amount, 5);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('catch-up shows generic error on failure', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final yesterday = habitDateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final setupRepo = HabitRepository(db);
    final id = await setupRepo.createHabit(
      name: 'Read',
      startDate: yesterday,
      goalAmount: 5,
      unit: 'min',
    );
    await setupRepo.addAmount(id, yesterday, 3);

    final fake = _ThrowingHabitRepository(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          habitRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: HabitsStatsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Add 2 min'), findsOneWidget);

    await tester.tap(find.text('Add 2 min'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Could not update this day. Try again.'), findsOneWidget);
    expect(find.textContaining('Could not update:'), findsNothing);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });
}
