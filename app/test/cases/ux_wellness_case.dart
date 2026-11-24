import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/design/components/rows.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/countdown_repository.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/domain/habits/date_key.dart';
import 'package:ephemeron/features/countdowns/presentation/countdowns_screen.dart';
import 'package:ephemeron/features/focus/presentation/focus_screen.dart';
import 'package:ephemeron/features/habits/presentation/habits_screen.dart';
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
    (call) async => null,
  );
  messenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (message) async =>
        const StandardMessageCodec().encodeMessage(const <Object?>[]),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

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
    expect(find.byType(AppCountdownCard), findsOneWidget);
    expect(tester.takeException(), isNull);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('running focus view scrolls without overflow at 320dp', (
    WidgetTester tester,
  ) async {
    _mockPlatformChannels();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: 'short-screen',
            startUtc: now - const Duration(hours: 13).inMilliseconds,
            targetEndUtc: Value(
              now + const Duration(minutes: 5).inMilliseconds,
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

    expect(find.textContaining('Recovered after app restart'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.dragUntilVisible(
      find.text('Finish'),
      find.byType(ListView),
      const Offset(0, -160),
    );
    expect(find.text('Finish'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('habit tile fits a 320dp screen with a goal and seven dots', (
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
    final row = tester.widget<AppHabitRow>(find.byType(AppHabitRow));
    expect(row.weekDots, hasLength(7));
    expect(row.done, isTrue);
    expect(tester.takeException(), isNull);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('habit row icon actions keep 48dp targets at 320dp and 2x text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = HabitRepository(db);
    await repo.createHabit(
      name: 'Read a long book',
      startDate: '2026-01-01',
      goalAmount: 10,
      unit: 'count',
      increment: 2,
    );

    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const HabitsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final icon in [Icons.skip_next_outlined, Icons.more_vert]) {
      final target = find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(IconButton),
      );
      expect(target, findsOneWidget, reason: 'missing action $icon');
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(48), reason: 'width of $icon');
      expect(size.height, greaterThanOrEqualTo(48), reason: 'height of $icon');
    }
    expect(tester.takeException(), isNull);
    expect(
      reportedErrors,
      isEmpty,
      reason: reportedErrors.map((e) => e.exceptionAsString()).join('\n'),
    );
    FlutterError.onError = previousOnError;

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('habit day strip initial scroll offset is at maxScrollExtent', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HabitsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final listFinder = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.horizontal,
    );
    expect(listFinder, findsOneWidget);
    final list = tester.widget<ListView>(listFinder);
    final position = list.controller!.position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, closeTo(position.maxScrollExtent, 20.0));

    final today = habitDateKey(DateTime.now());
    final todayChip = find.byWidgetPredicate(
      (w) => w is HabitDayChip && habitDateKey(w.day) == today,
    );
    expect(todayChip, findsOneWidget);
    expect(tester.takeException(), isNull);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });
}
