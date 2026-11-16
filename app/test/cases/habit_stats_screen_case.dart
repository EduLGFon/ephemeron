import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/domain/habits/date_key.dart';
import 'package:ephemeron/features/habits/presentation/habits_stats_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
