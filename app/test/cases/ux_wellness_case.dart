import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/countdown_repository.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/domain/habits/date_key.dart';
import 'package:ephemeron/features/countdowns/presentation/countdowns_screen.dart';
import 'package:ephemeron/features/focus/presentation/focus_screen.dart';
import 'package:ephemeron/features/habits/presentation/habits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('habit day strip covers 14 days ending today', () {
    final today = DateTime(2026, 11, 11);
    final days = habitDayStripDays(today);
    expect(days, hasLength(14));
    expect(days.first, DateTime(2026, 10, 29));
    expect(days.last, DateTime(2026, 11, 11));
    expect(days.map(habitDateKey).toSet(), hasLength(14));
  });

  test('countdown day badge and relative label', () {
    expect(countdownDayBadge(null), '-');
    expect(countdownDayBadge(-4), 'Past');
    expect(countdownDayBadge(0), '0');
    expect(countdownDayBadge(3), '3');

    expect(countdownRelativeLabel(0), 'today');
    expect(countdownRelativeLabel(1), 'tomorrow');
    expect(countdownRelativeLabel(3), 'in 3 days');
    expect(countdownRelativeLabel(-1), 'yesterday');
    expect(countdownRelativeLabel(-5), '5 days ago');
  });

  test('custom focus and break durations are validated', () {
    expect(validateFocusMinutes('1', isBreak: false), isNull);
    expect(validateFocusMinutes('240', isBreak: false), isNull);
    expect(validateFocusMinutes('1', isBreak: true), isNull);
    expect(validateFocusMinutes('60', isBreak: true), isNull);

    expect(validateFocusMinutes('', isBreak: false), 'Enter minutes.');
    expect(
      validateFocusMinutes('abc', isBreak: false),
      'Enter a whole number.',
    );
    expect(validateFocusMinutes('0', isBreak: false), 'Enter 1-240 minutes.');
    expect(validateFocusMinutes('241', isBreak: false), 'Enter 1-240 minutes.');
    expect(validateFocusMinutes('0', isBreak: true), 'Enter 1-60 minutes.');
    expect(validateFocusMinutes('61', isBreak: true), 'Enter 1-60 minutes.');
  });

  testWidgets('countdown card fits a 320dp screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = CountdownRepository(db);
    final nextYear = DateTime.now().year + 1;
    const title = 'A long countdown title that must ellipsize cleanly';
    await repo.createCountdown(title: title, targetDate: '$nextYear-06-01');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CountdownsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(title), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('habit tile fits a 320dp screen with a goal', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    final id = await repo.createHabit(
      name: 'Read a long book',
      startDate: '2026-01-01',
      goalAmount: 10,
      unit: 'min',
      increment: 2,
    );
    await repo.addAmount(id, habitDateKey(DateTime.now()), 10);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Read a long book'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    expect(tester.takeException(), isNull);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });
}
