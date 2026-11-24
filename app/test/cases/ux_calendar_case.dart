// Calendar UX polish: humanized agenda headers, checked view choices, the
// month empty state action, and safe unmounting while a cache rebuild runs.
import 'package:ephemeron/app/session/session_restore.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/calendar/presentation/agenda_view.dart';
import 'package:ephemeron/features/calendar/presentation/calendar_screen.dart';
import 'package:ephemeron/features/calendar/presentation/month_view.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_fixtures.dart';

class _FixedWindow extends CalendarState {
  _FixedWindow(this.window);
  final CalendarWindow window;
  @override
  CalendarWindow build() => window;
}

void main() {
  late AppDatabase db;
  setUpAll(() => db = newTestDb());
  setUp(() => resetTestDb(db));
  tearDownAll(() => db.close());
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('agendaDayLabel humanizes today and tomorrow', () {
    final today = DateTime(2026, 11, 11);
    String label(DateTime day) => agendaDayLabel(
      day,
      today: today,
      weekdayShort: 'Mon',
      monthShort: 'Nov',
    );

    expect(label(DateTime(2026, 11, 11)), 'Today, Nov 11');
    expect(label(DateTime(2026, 11, 12)), 'Tomorrow, Nov 12');
    expect(label(DateTime(2026, 11, 10)), 'Mon, Nov 10');
  });

  test('agendaDayLabel includes the year outside the current year', () {
    expect(
      agendaDayLabel(
        DateTime(2025, 12, 29),
        today: DateTime(2026, 11, 11),
        weekdayShort: 'Mon',
        monthShort: 'Dec',
      ),
      'Mon, Dec 29, 2025',
    );
  });

  test('view choice selection includes the multi-day count', () {
    final week = CalendarWindow(
      anchor: DateTime(2026, 11, 11),
      view: CalendarViewKind.multiDay,
      dayCount: 7,
    );
    expect(
      isCalendarViewChoiceSelected(
        view: CalendarViewKind.multiDay,
        dayCount: 7,
        window: week,
      ),
      isTrue,
    );
    expect(
      isCalendarViewChoiceSelected(
        view: CalendarViewKind.multiDay,
        dayCount: 3,
        window: week,
      ),
      isFalse,
    );
    expect(
      isCalendarViewChoiceSelected(
        view: CalendarViewKind.month,
        dayCount: 1,
        window: week,
      ),
      isFalse,
    );

    final day = CalendarWindow(
      anchor: DateTime(2026, 11, 11),
      view: CalendarViewKind.day,
    );
    expect(
      isCalendarViewChoiceSelected(
        view: CalendarViewKind.day,
        dayCount: 1,
        window: day,
      ),
      isTrue,
    );
  });

  testWidgets('month empty state offers Add event for the selected day', (
    tester,
  ) async {
    final anchor = DateTime.now();
    final window = CalendarWindow(anchor: anchor, view: CalendarViewKind.month);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          calendarStateProvider.overrideWith(() => _FixedWindow(window)),
        ],
        child: MaterialApp(
          // The default sparkle splash needs a Vulkan-only shader that the
          // Skia test backend cannot load.
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: const Scaffold(body: MonthView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Nothing on this day'), findsOneWidget);
    await tester.tap(find.text('Add event'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('calendar screen survives unmount during a cache rebuild', (
    tester,
  ) async {
    final window = CalendarWindow(
      anchor: DateTime.now(),
      view: CalendarViewKind.month,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          calendarStateProvider.overrideWith(() => _FixedWindow(window)),
        ],
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CalendarScreen)),
    );
    container.read(initialRestoreDoneProvider.notifier).markDone();
    container.read(occurrenceDirtyProvider.notifier).markDirty();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);

    await tester.pump();
  });

  testWidgets('late restore coalesces the fallback into one cache build', (
    tester,
  ) async {
    final repo = _RecordingOccurrenceRepository(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          occurrenceRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );
    await tester.pump();
    expect(repo.ranges, isEmpty);

    // Fire the 2 s fallback without drawing a frame so a late restore can
    // still land before the scheduled build runs.
    await tester.binding.delayed(const Duration(seconds: 2));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CalendarScreen)),
    );
    final restored = CalendarWindow(
      anchor: DateTime(2020, 6, 1),
      view: CalendarViewKind.year,
    );
    container
        .read(calendarStateProvider.notifier)
        .restore(restored.view, restored.anchor);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.ranges, hasLength(1));
    expect(repo.ranges.single, restored.cacheRange);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

class _RecordingOccurrenceRepository extends OccurrenceRepository {
  _RecordingOccurrenceRepository(super.db);

  final List<CalendarRange> ranges = [];

  @override
  Future<int> rebuildWindow({
    required DateTime windowStartUtc,
    required DateTime windowEndUtc,
  }) async {
    ranges.add(CalendarRange(fromUtc: windowStartUtc, toUtc: windowEndUtc));
    return 0;
  }
}
