import 'package:drift/drift.dart' show Value;

import 'package:ephemeron/core/db/db_provider.dart';

import 'package:ephemeron/core/design/components/rows.dart';

import 'package:ephemeron/core/design/components/visuals.dart';

import 'package:ephemeron/data/drift/app_database.dart';

import 'package:ephemeron/data/repositories/countdown_repository.dart';

import 'package:ephemeron/data/repositories/habit_repository.dart';

import 'package:ephemeron/domain/habits/date_key.dart';

import 'package:ephemeron/features/countdowns/presentation/countdowns_screen.dart';

import 'package:ephemeron/features/focus/presentation/focus_screen.dart';

import 'package:ephemeron/features/habits/presentation/habit_heatmap_screen.dart';

import 'package:ephemeron/features/habits/presentation/habits_screen.dart';

import 'package:material_ui/material_ui.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';

import '../support/test_fixtures.dart';

import 'package:shared_preferences/shared_preferences.dart';

late AppDatabase db;

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

Future<void> _unmount(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

Widget _scaled(Widget home) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: home,
    ),
  );
}

void main() {
  setUpAll(() {
    db = newTestDb();
  });
  setUp(() => resetTestDb(db));
  tearDownAll(() async {
    await db.close();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _mockPlatformChannels();
  });

  test('heatmap values form weeks of seven Monday-first days', () {
    final values = habitHeatmapValues(
      today: DateTime(2026, 11, 18),
      byDay: {'2026-11-18': 3},
    );
    expect(values, hasLength(16 * 7));
    // 2026-11-18 is a Wednesday: index 15 full weeks plus Monday and Tuesday.
    expect(values[15 * 7 + 2], 3);
    expect(values.where((value) => value != 0), hasLength(1));
  });

  testWidgets('habits screen toggles, skips and opens the heatmap', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = HabitRepository(db);
    final sectionId = await repo.createSection('Health');
    final id = await repo.createHabit(
      name: 'Read',
      sectionId: sectionId,
      startDate: '2026-01-01',
      goalAmount: 10,
      unit: 'count',
    );
    final today = habitDateKey(DateTime.now());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: _scaled(const HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.byType(AppHabitRow), findsOneWidget);
    expect(find.byType(HabitDayChip), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Read'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // A row tap advances progress; the leading circle is what marks done.
    final log = await repo.logFor(id, today);
    expect(log?.amount, 1);
    expect(log?.done, isFalse);

    await tester.tap(find.byTooltip('Skip day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect((await repo.logFor(id, today))?.skipped, isTrue);

    await tester.tap(find.byTooltip('Habit heatmap'));
    await settle(tester);
    expect(find.text('Habit activity'), findsOneWidget);
    expect(find.byType(AppHeatmap), findsOneWidget);
    final heatmap = tester.widget<AppHeatmap>(find.byType(AppHeatmap));
    expect(heatmap.values, hasLength(112));
    expect(tester.takeException(), isNull);

    await _unmount(tester, db);
  });

  testWidgets('countdowns screen fits 320dp with 200% text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CountdownRepository(db);
    final nextYear = DateTime.now().year + 1;
    await repo.createCountdown(
      title: 'A long countdown title',
      targetDate: '$nextYear-06-01',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: _scaled(const CountdownsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('A long countdown title'), findsOneWidget);
    expect(find.byType(AppCountdownCard), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _unmount(tester, db);
  });

  testWidgets('focus digits run in a RepaintBoundary and pause resumes', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'wellness-focus',
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

    final face = find.byType(FocusTimeFace);
    expect(face, findsOneWidget);
    expect(
      find.descendant(of: face, matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(RegExp('Focus time remaining')),
      findsOneWidget,
    );

    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(FocusTimeFace), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _unmount(tester, db);
  });

  testWidgets('wellness screens fit 320dp with 200% text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final habits = HabitRepository(db);
    final habitId = await habits.createHabit(
      name: 'Read a long book every day',
      startDate: '2026-01-01',
      goalAmount: 10,
      unit: 'min',
    );
    final countdowns = CountdownRepository(db);
    final nextYear = DateTime.now().year + 1;
    await countdowns.createCountdown(
      title: 'A long countdown title',
      targetDate: '$nextYear-06-01',
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'wellness-focus-sized',
            habitId: Value(habitId),
            startUtc: now - const Duration(minutes: 5).inMilliseconds,
            targetEndUtc: Value(
              now + const Duration(minutes: 20).inMilliseconds,
            ),
            phase: const Value('focus'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    for (final screen in <Widget>[
      const HabitsScreen(),
      const CountdownsScreen(),
      const FocusScreen(),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: _scaled(screen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull, reason: '$screen overflowed');
    }

    await _unmount(tester, db);
  });

  testWidgets('focus start view fits 320dp with 200% text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: _scaled(const FocusScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Focus'), findsWidgets);
    await tester.dragUntilVisible(
      find.textContaining('Start 25 min focus'),
      find.byType(ListView),
      const Offset(0, -160),
    );
    expect(find.textContaining('Start 25 min focus'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _unmount(tester, db);
  });
}
