import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/calendar/presentation/year_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: 'cal1',
          name: 'c',
          createdAt: now,
          updatedAt: now,
        ),
      );
  Future<void> ev(String id, DateTime day, int hour) async {
    final start = DateTime(day.year, day.month, day.day, hour).toUtc();
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: id,
            calendarId: 'cal1',
            title: Value(id),
            startUtc: Value(start.millisecondsSinceEpoch),
            endUtc: Value(
              start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  await ev('e1', DateTime(2026, 3, 2), 10);
  await ev('e2', DateTime(2026, 3, 3), 10);
  await ev('e3', DateTime(2026, 3, 5), 10);
  await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          id: 't1',
          title: const Value('Task'),
          plannedDate: const Value('2026-04-10'),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

class _FixedWindow extends CalendarState {
  _FixedWindow(this.window);
  final CalendarWindow window;
  @override
  CalendarWindow build() => window;
}

Future<void> _pump(WidgetTester tester, AppDatabase db) async {
  final window = CalendarWindow(
    anchor: DateTime(2026, 6, 1),
    view: CalendarViewKind.year,
  );
  await OccurrenceRepository(
    db,
  ).rebuildWindow(windowStartUtc: window.fromUtc, windowEndUtc: window.toUtc);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        calendarStateProvider.overrideWith(() => _FixedWindow(window)),
      ],
      child: const MaterialApp(home: Scaffold(body: YearView())),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tearDown(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('year view shows summary and month cards', (tester) async {
    final db = _db();
    await _seed(db);
    await _pump(tester, db);

    expect(find.textContaining('Events: 3'), findsOneWidget);
    expect(find.textContaining('Tasks: 1'), findsOneWidget);
    expect(find.textContaining('Active days: 4'), findsOneWidget);
    expect(find.textContaining('Busiest: Mar (3)'), findsOneWidget);
    expect(find.textContaining('Longest streak: 2'), findsOneWidget);
    expect(find.byType(Card, skipOffstage: false), findsNWidgets(12));

    await _tearDown(tester, db);
  });

  testWidgets('tapping a month card opens that month', (tester) async {
    final db = _db();
    await _seed(db);
    await _pump(tester, db);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(YearView)),
    );
    final notifier = container.read(calendarStateProvider.notifier);

    // Tap March card (semantics label)
    await tester.tap(find.bySemanticsLabel(RegExp('Open March 2026')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final w = container.read(calendarStateProvider);
    expect(w.view, CalendarViewKind.month);
    expect(w.anchor, DateTime(2026, 3, 1));

    // also direct openMonth
    notifier.openMonth(2026, 4);
    final w2 = container.read(calendarStateProvider);
    expect(w2.view, CalendarViewKind.month);
    expect(w2.anchor, DateTime(2026, 4, 1));

    await _tearDown(tester, db);
  });

  test('openMonth sets month window', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(calendarStateProvider.notifier);
    notifier.openMonth(2026, 7);
    final w = container.read(calendarStateProvider);
    expect(w.view, CalendarViewKind.month);
    expect(w.anchor, DateTime(2026, 7, 1));
    expect(w.dayCount, 1);
  });

  test('shiftMonths(12) moves a year', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(calendarStateProvider.notifier);
    notifier.restore(CalendarViewKind.year, DateTime(2026, 6, 1));
    notifier.shiftMonths(12);
    expect(container.read(calendarStateProvider).anchor.year, 2027);
    notifier.shiftMonths(-12);
    expect(container.read(calendarStateProvider).anchor.year, 2026);
  });
}
