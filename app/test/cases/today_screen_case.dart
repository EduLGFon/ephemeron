import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/design/layout.dart';
import 'package:ephemeron/core/time/time.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/countdown_repository.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/calendar/application/calendar_cache_coordinator.dart';
import 'package:ephemeron/features/habits/application/habits_providers.dart';
import 'package:ephemeron/features/today/application/today_providers.dart';
import 'package:ephemeron/features/today/presentation/today_screen.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fixture {
  _Fixture(this.db, this.now, this.todayKey);

  final AppDatabase db;
  final DateTime now;
  final String todayKey;
}

Future<_Fixture> _fixture() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final base = DateTime.now();
  final now = DateTime(base.year, base.month, base.day, 9, 30);
  return _Fixture(db, now, dateKey(now));
}

OccurrenceCacheData _event(_Fixture fixture) {
  final start = DateTime(
    fixture.now.year,
    fixture.now.month,
    fixture.now.day,
    10,
  );
  final end = start.add(const Duration(hours: 1));
  return OccurrenceCacheData(
    id: 'occ-1',
    eventId: 'event-1',
    title: 'Standup',
    startUtc: start.toUtc().millisecondsSinceEpoch,
    endUtc: end.toUtc().millisecondsSinceEpoch,
    dayKey: fixture.todayKey,
    sourceType: 'event',
  );
}

Widget _app({
  required _Fixture fixture,
  required List<OccurrenceCacheData> occurrences,
  AppLayout layout = AppLayout.compact,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(fixture.db),
      deviceNowProvider.overrideWithValue(() => fixture.now),
      calendarRangeOccurrencesProvider.overrideWith(
        (ref, range) => Stream<List<OccurrenceCacheData>>.value(occurrences),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: AppLayoutScope(
          layout: layout,
          child: TodayScreen(now: fixture.now),
        ),
      ),
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _unmount(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
  await tester.pump();
}

void main() {
  testWidgets('renders hero, agenda, habit and countdown without a spinner', (
    tester,
  ) async {
    _setSize(tester, const Size(400, 800));
    final fixture = await _fixture();
    final taskRepo = TaskRepository(fixture.db);
    final habitRepo = HabitRepository(fixture.db);
    final countdownRepo = CountdownRepository(fixture.db);
    await taskRepo.createTask(
      title: 'Pay rent',
      dueDate: fixture.todayKey,
      dueTime: 600,
    );
    final habitId = await habitRepo.createHabit(
      name: 'Stretch',
      startDate: fixture.todayKey,
    );
    await countdownRepo.createCountdown(
      title: 'Trip',
      targetDate: dateKey(fixture.now.add(const Duration(days: 10))),
    );

    await tester.pumpWidget(
      _app(
        fixture: fixture,
        occurrences: <OccurrenceCacheData>[_event(fixture)],
      ),
    );
    await _settle(tester);

    expect(find.text('Standup'), findsWidgets);
    expect(find.textContaining('in 30 min'), findsOneWidget);
    expect(find.text('Pay rent'), findsOneWidget);
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // One tap toggles the habit for today and the stream reflects it.
    await tester.tap(find.byKey(ValueKey<String>('today-habit-$habitId')));
    await _settle(tester);
    final log = await habitRepo.logFor(habitId, habitTodayKey());
    expect(log?.done, isTrue);
    expect(tester.takeException(), isNull);

    await _unmount(tester, fixture.db);
  });

  testWidgets('shows the calm empty state when the day is clear', (
    tester,
  ) async {
    _setSize(tester, const Size(400, 800));
    final fixture = await _fixture();

    await tester.pumpWidget(
      _app(fixture: fixture, occurrences: const <OccurrenceCacheData>[]),
    );
    await _settle(tester);

    expect(find.text('A clear day'), findsOneWidget);
    expect(find.text('Add something'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await _unmount(tester, fixture.db);
  });

  testWidgets('expanded layout uses the two-column body', (tester) async {
    _setSize(tester, const Size(1000, 900));
    final fixture = await _fixture();
    await TaskRepository(fixture.db)
        .createTask(title: 'Pay rent', dueDate: fixture.todayKey);

    await tester.pumpWidget(
      _app(
        fixture: fixture,
        occurrences: <OccurrenceCacheData>[_event(fixture)],
        layout: AppLayout.expanded,
      ),
    );
    await _settle(tester);

    expect(
      find.byKey(const ValueKey<String>('today-wide-body')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('today-compact-body')),
      findsNothing,
    );

    await _unmount(tester, fixture.db);
  });

  testWidgets('renders at 320dp and 200% text without overflow', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 640));
    final fixture = await _fixture();
    await TaskRepository(fixture.db)
        .createTask(title: 'Pay rent', dueDate: fixture.todayKey, dueTime: 600);
    await HabitRepository(fixture.db)
        .createHabit(name: 'Stretch', startDate: fixture.todayKey);
    await CountdownRepository(fixture.db).createCountdown(
      title: 'Trip',
      targetDate: dateKey(fixture.now.add(const Duration(days: 10))),
    );

    await tester.pumpWidget(
      _app(
        fixture: fixture,
        occurrences: <OccurrenceCacheData>[_event(fixture)],
        textScale: 2,
      ),
    );
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('today-compact-body')),
      findsOneWidget,
    );

    await _unmount(tester, fixture.db);
  });

  testWidgets('first frame is stable while data loads', (tester) async {
    _setSize(tester, const Size(400, 800));
    final fixture = await _fixture();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(fixture.db),
          deviceNowProvider.overrideWithValue(() => fixture.now),
          todayOccurrencesProvider.overrideWithValue(
            const AsyncValue<List<OccurrenceCacheData>>.loading(),
          ),
          todayTasksProvider.overrideWithValue(
            const AsyncValue<TodayTaskBuckets>.loading(),
          ),
          todayHabitEntriesProvider.overrideWithValue(
            const AsyncValue.loading(),
          ),
          todayCountdownsProvider.overrideWithValue(const AsyncValue.loading()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1)),
            child: AppLayoutScope(
              layout: AppLayout.compact,
              child: TodayScreen(now: fixture.now),
            ),
          ),
        ),
      ),
    );
    // First frame only: providers are still loading, no settle.
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('today-compact-body')),
      findsOneWidget,
    );
    expect(find.text('A clear day'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    await _unmount(tester, fixture.db);
  });
}
