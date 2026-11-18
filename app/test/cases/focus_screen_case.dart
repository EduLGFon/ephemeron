import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/focus_repository.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/domain/habits/date_key.dart';
import 'package:ephemeron/features/focus/presentation/focus_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _mockPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('ephemeron/alarms'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('ephemeron/system'),
    (call) async => call.method == 'canPostNotifications' ? true : null,
  );
  messenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (message) async =>
        const StandardMessageCodec().encodeMessage(const <Object?>[]),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('running session finishes from the screen', (
    WidgetTester tester,
  ) async {
    _mockPlatformChannels();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = FocusRepository(db);
    await repo.startSession(durationMin: 25);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: FocusScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Finish'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Focus time remaining')),
      findsOneWidget,
    );
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(await repo.currentSession(), isNull);
    // Close the db and unmount inside the test body so Drift's
    // stream-close timer fires before the pending-timer check.
    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('running focus shows linked habit live goal progress', (
    WidgetTester tester,
  ) async {
    _mockPlatformChannels();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final habits = HabitRepository(db);
    final habitId = await habits.createHabit(
      name: 'Deep work',
      startDate: habitDateKey(DateTime.now()),
      goalAmount: 10,
      unit: 'min',
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'linked',
            habitId: Value(habitId),
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
        child: const MaterialApp(home: FocusScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Deep work'), findsOneWidget);
    final progress = tester.widget<Text>(
      find.textContaining(RegExp(r'\d+\.\d%')),
    );
    final pct = double.parse(
      RegExp(r'(\d+\.\d)%').firstMatch(progress.data!)!.group(1)!,
    );
    expect(pct, greaterThanOrEqualTo(49.5));
    expect(pct, lessThan(52.0));
    expect(find.textContaining('/ 10 min'), findsOneWidget);
    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('finishing focus credits minute progress and undo restores it', (
    WidgetTester tester,
  ) async {
    _mockPlatformChannels();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final habits = HabitRepository(db);
    final habitId = await habits.createHabit(
      name: 'Run',
      startDate: habitDateKey(DateTime.now()),
      goalAmount: 10,
      unit: 'min',
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'credit',
            habitId: Value(habitId),
            startUtc: now - 6 * 60000,
            targetEndUtc: Value(now + 19 * 60000),
            phase: const Value('focus'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FocusScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Stop'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final today = habitDateKey(DateTime.now());
    var log = await habits.logFor(habitId, today);
    expect(log?.amount, 6);
    expect(log?.done, isFalse);

    await tester.tap(find.text('Undo'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    log = await habits.logFor(habitId, today);
    expect(log?.amount, 0);
    expect(log?.done, isFalse);

    await tester.pumpWidget(Container());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await db.close();
  });

  testWidgets('finishing a break does not credit the linked habit', (
    WidgetTester tester,
  ) async {
    _mockPlatformChannels();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final habits = HabitRepository(db);
    final habitId = await habits.createHabit(
      name: 'Run',
      startDate: habitDateKey(DateTime.now()),
      goalAmount: 10,
      unit: 'min',
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'break',
            habitId: Value(habitId),
            startUtc: now - 6 * 60000,
            targetEndUtc: Value(now + 4 * 60000),
            phase: const Value('break'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FocusScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Stop'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final today = habitDateKey(DateTime.now());
    expect(await habits.logFor(habitId, today), isNull);
    expect(find.textContaining('Credited'), findsNothing);

    await tester.pumpWidget(Container());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await db.close();
  });

  testWidgets('pause finishes the segment and resume keeps the remainder', (
    WidgetTester tester,
  ) async {
    _mockPlatformChannels();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = FocusRepository(db);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'paused',
            startUtc: now - const Duration(minutes: 5).inMilliseconds,
            targetEndUtc: Value(
              now + const Duration(minutes: 20).inMilliseconds,
            ),
            phase: const Value('focus'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: FocusScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(await repo.currentSession(), isNull);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.textContaining('left'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final resumed = await repo.currentSession();
    expect(resumed, isNotNull);
    expect(resumed!.phase, 'focus');
    final remaining = resumed.targetEndUtc! - resumed.startUtc;
    expect(
      remaining,
      closeTo(const Duration(minutes: 20).inMilliseconds, 2000),
    );

    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  });
}
