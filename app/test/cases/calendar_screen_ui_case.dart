// Calendar screen chrome and adaptive defaults: fresh-install day/week views,
// persisted view preservation, menu switching, empty/error states, narrow and
// large text layouts, and coordinator rebuilds after occurrence invalidation.
import 'package:drift/native.dart';
import 'package:ephemeron/app/session/session_restore.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/design/components/app_states.dart';
import 'package:ephemeron/core/design/layout.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/calendar/presentation/agenda_view.dart';
import 'package:ephemeron/features/calendar/presentation/calendar_screen.dart';
import 'package:ephemeron/features/calendar/presentation/month_view.dart';
import 'package:ephemeron/features/calendar/presentation/timeline/timeline_view.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

final _anchor = DateTime(2026, 11, 4);

class _FixedWindow extends CalendarState {
  _FixedWindow(this.window);
  final CalendarWindow window;
  @override
  CalendarWindow build() => window;
}

class _RecordingOccurrenceRepository extends OccurrenceRepository {
  _RecordingOccurrenceRepository(super.db);

  final List<CalendarRange> ranges = <CalendarRange>[];

  @override
  Future<int> rebuildWindow({
    required DateTime windowStartUtc,
    required DateTime windowEndUtc,
  }) async {
    ranges.add(CalendarRange(fromUtc: windowStartUtc, toUtc: windowEndUtc));
    return 0;
  }
}

class _FailingOccurrenceRepository extends OccurrenceRepository {
  _FailingOccurrenceRepository(super.db);

  @override
  Future<int> rebuildWindow({
    required DateTime windowStartUtc,
    required DateTime windowEndUtc,
  }) async {
    throw StateError('calendar rebuild failed');
  }
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<ProviderContainer> _pumpCalendar(
  WidgetTester tester,
  AppDatabase db, {
  Size size = const Size(400, 800),
  AppLayout? layout,
  List<Override> overrides = const <Override>[],
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget home = Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: const CalendarScreen(),
    ),
  );
  Widget app = MaterialApp(
    // The default sparkle splash needs a Vulkan-only shader that the Skia
    // test backend cannot load.
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: home,
  );
  if (layout != null) {
    app = AppLayoutScope(layout: layout, child: app);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        ...overrides,
      ],
      child: app,
    ),
  );
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CalendarScreen)),
  );
  container.read(initialRestoreDoneProvider.notifier).markDone();
  await _pumpFrames(tester);
  return container;
}

Future<void> _tearDown(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('compact fresh install opens Day and persists it', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpCalendar(tester, db);

    expect(find.byType(TimelineView), findsOneWidget);
    expect(tester.widget<TimelineView>(find.byType(TimelineView)).dayCount, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('calendar.view'), 'day');
    expect(prefs.getInt('calendar.dayCount'), 1);

    await _tearDown(tester, db);
  });

  testWidgets('expanded fresh install opens a full week and persists it', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpCalendar(
      tester,
      db,
      size: const Size(1200, 900),
      layout: AppLayout.expanded,
    );

    expect(find.byType(TimelineView), findsOneWidget);
    expect(tester.widget<TimelineView>(find.byType(TimelineView)).dayCount, 7);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('calendar.view'), 'multiDay');
    expect(prefs.getInt('calendar.dayCount'), 7);

    await _tearDown(tester, db);
  });

  testWidgets('a persisted view is not replaced by the adaptive default', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'calendar.view': 'month',
    });
    final db = _db();
    await _pumpCalendar(
      tester,
      db,
      overrides: <Override>[
        calendarStateProvider.overrideWith(
          () => _FixedWindow(
            CalendarWindow(anchor: _anchor, view: CalendarViewKind.month),
          ),
        ),
      ],
    );

    expect(find.byType(MonthView), findsOneWidget);
    expect(find.byType(TimelineView), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('calendar.view'), 'month');

    await _tearDown(tester, db);
  });

  testWidgets('view menu switches the visible view and persists it', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpCalendar(tester, db);
    expect(find.byType(TimelineView), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<CalendarViewChoice>, 'Agenda'),
    );
    await tester.pumpAndSettle();
    await _pumpFrames(tester);
    expect(find.byType(AgendaView), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<CalendarViewChoice>, 'Month'),
    );
    await tester.pumpAndSettle();
    await _pumpFrames(tester);
    expect(find.byType(MonthView), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('calendar.view'), 'month');

    await _tearDown(tester, db);
  });

  testWidgets('agenda shows its empty state when the range is clear', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpCalendar(tester, db);

    await tester.tap(find.byKey(const Key('calendar-view-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<CalendarViewChoice>, 'Agenda'),
    );
    await tester.pumpAndSettle();
    await _pumpFrames(tester);

    expect(find.byType(AgendaView), findsOneWidget);
    expect(find.text('Nothing scheduled'), findsOneWidget);
    expect(find.byType(AppErrorState), findsNothing);

    await _tearDown(tester, db);
  });

  testWidgets('a failed range rebuild shows the screen error state', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpCalendar(
      tester,
      db,
      overrides: <Override>[
        occurrenceRepositoryProvider.overrideWithValue(
          _FailingOccurrenceRepository(db),
        ),
      ],
    );

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Could not load calendar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tearDown(tester, db);
  });

  testWidgets('chrome fits 320dp at 200 percent text', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpCalendar(tester, db, size: const Size(320, 640), textScale: 2);

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.byKey(const Key('calendar-view-menu')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tearDown(tester, db);
  });

  testWidgets('dirty occurrences rebuild through a fresh coordinator', (
    WidgetTester tester,
  ) async {
    final db = _db();
    final repository = _RecordingOccurrenceRepository(db);
    final container = await _pumpCalendar(
      tester,
      db,
      overrides: <Override>[
        occurrenceRepositoryProvider.overrideWithValue(repository),
      ],
    );
    expect(repository.ranges, hasLength(1));

    container.read(occurrenceDirtyProvider.notifier).markDirty();
    await _pumpFrames(tester);

    expect(repository.ranges, hasLength(2));
    await _tearDown(tester, db);
  });
}
