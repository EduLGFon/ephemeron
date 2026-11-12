// Calendar atomic load: a new view range shows either the complete
// occurrence set or a loading state, never a partial mix of ranges.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/calendar/presentation/calendar_error_banner.dart';
import 'package:ephemeron/features/calendar/presentation/month_view.dart';
import 'package:ephemeron/features/calendar/presentation/timeline/timeline_view.dart';
import 'package:ephemeron/features/calendar/presentation/year_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

final _rangeA = CalendarWindow(
  anchor: DateTime(2027, 3, 1),
  view: CalendarViewKind.day,
);
final _rangeB = CalendarWindow(
  anchor: DateTime(2027, 6, 1),
  view: CalendarViewKind.day,
);

/// Empty month range used to prove a range switch never claims "nothing".
final _emptyMonth = CalendarWindow(
  anchor: DateTime(2028, 1, 15),
  view: CalendarViewKind.month,
);

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  Future<void> calendar(String id, String name) async {
    await db
        .into(db.calendars)
        .insert(
          CalendarsCompanion.insert(
            id: id,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> event(
    String id,
    String calendarId,
    String title,
    DateTime day,
    int hour,
  ) async {
    final start = DateTime(day.year, day.month, day.day, hour).toUtc();
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: id,
            calendarId: calendarId,
            title: Value(title),
            startUtc: Value(start.millisecondsSinceEpoch),
            endUtc: Value(
              start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  await calendar('cal1', 'One');
  await calendar('cal2', 'Two');
  await event('a1', 'cal1', 'Alpha One', _rangeA.anchor, 10);
  await event('a2', 'cal2', 'Alpha Two', _rangeA.anchor, 12);
  await event('b1', 'cal1', 'Beta One', _rangeB.anchor, 9);
  await event('b2', 'cal2', 'Beta Two', _rangeB.anchor, 11);
}

class _FixedWindow extends CalendarState {
  _FixedWindow(this.window);
  final CalendarWindow window;
  @override
  CalendarWindow build() => window;
}

class _TimelineHost extends ConsumerWidget {
  const _TimelineHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(calendarStateProvider);
    return TimelineView(anchor: window.anchor, dayCount: window.dayCount);
  }
}

/// Occurrence stream that always fails, for the error-state tests.
final _failingOccurrences = windowOccurrencesProvider.overrideWith(
  (ref, range) => Stream<List<OccurrenceCacheData>>.error(StateError('boom')),
);

Future<void> _pumpMonth(
  WidgetTester tester,
  AppDatabase db,
  CalendarWindow window, {
  bool failOccurrences = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        calendarStateProvider.overrideWith(() => _FixedWindow(window)),
        if (failOccurrences) _failingOccurrences,
      ],
      child: const MaterialApp(home: Scaffold(body: MonthView())),
    ),
  );
  await _pumpTwice(tester);
}

Future<void> _revealAgenda(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tearDown(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
}

Future<void> _pumpTwice(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('built range defaults to the cache range and mark replaces it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cache = container.read(calendarCacheRangeProvider);

    expect(container.read(calendarBuiltRangeProvider), cache);

    final other = CalendarRange(
      fromUtc: DateTime.utc(2030, 1, 1),
      toUtc: DateTime.utc(2030, 2, 1),
    );
    container.read(calendarBuiltRangeProvider.notifier).markBuilt(other);

    expect(container.read(calendarBuiltRangeProvider), other);
  });

  test('source map stays empty until the cache range is built', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cacheBefore = container.read(calendarCacheRangeProvider);
    expect(container.read(calendarBuiltRangeProvider), cacheBefore);

    container
        .read(calendarStateProvider.notifier)
        .restore(CalendarViewKind.month, DateTime(2030, 1, 15));

    expect(container.read(calendarCacheRangeProvider), isNot(cacheBefore));
    expect(container.read(calendarBuiltRangeProvider), cacheBefore);
    expect(await container.read(occurrenceSourceMapProvider.future), isEmpty);
  });

  testWidgets('switching ranges shows the complete set or a loading state', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _seed(db);
    final repo = OccurrenceRepository(db);
    await repo.rebuildWindow(
      windowStartUtc: _rangeA.fromUtc,
      windowEndUtc: _rangeA.toUtc,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          calendarStateProvider.overrideWith(() => _FixedWindow(_rangeA)),
        ],
        child: const MaterialApp(home: Scaffold(body: _TimelineHost())),
      ),
    );
    await _pumpTwice(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(_TimelineHost)),
    );
    container
        .read(calendarBuiltRangeProvider.notifier)
        .markBuilt(_rangeA.cacheRange);
    await _pumpTwice(tester);

    // Range A renders both calendars together.
    expect(find.text('Alpha One'), findsOneWidget);
    expect(find.text('Alpha Two'), findsOneWidget);

    // Switch to range B before it is built: no event from either range and
    // a loading indicator, never a partial mix.
    container
        .read(calendarStateProvider.notifier)
        .restore(CalendarViewKind.day, _rangeB.anchor);
    await _pumpTwice(tester);

    expect(find.text('Beta One'), findsNothing);
    expect(find.text('Beta Two'), findsNothing);
    expect(find.text('Alpha One'), findsNothing);
    expect(find.text('Alpha Two'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Building B exposes both calendars in one frame.
    await repo.rebuildWindow(
      windowStartUtc: _rangeB.fromUtc,
      windowEndUtc: _rangeB.toUtc,
    );
    container
        .read(calendarBuiltRangeProvider.notifier)
        .markBuilt(_rangeB.cacheRange);
    await _pumpTwice(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Beta One'), findsOneWidget);
    expect(find.text('Beta Two'), findsOneWidget);
    expect(find.text('Alpha One'), findsNothing);
    expect(find.text('Alpha Two'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await _tearDown(tester, db);
  });

  testWidgets('month range switch shows a loading agenda, not an empty one', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _seed(db);
    final repo = OccurrenceRepository(db);
    final windowA = CalendarWindow(
      anchor: _rangeA.anchor,
      view: CalendarViewKind.month,
    );
    await repo.rebuildWindow(
      windowStartUtc: windowA.fromUtc,
      windowEndUtc: windowA.toUtc,
    );
    await _pumpMonth(tester, db, windowA);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MonthView)),
    );

    // Switch to an unbuilt, empty month.
    container
        .read(calendarStateProvider.notifier)
        .restore(CalendarViewKind.month, _emptyMonth.anchor);
    await _pumpTwice(tester);
    await _revealAgenda(tester);

    expect(find.byKey(const Key('month-agenda-loading')), findsOneWidget);
    expect(find.byKey(const Key('month-agenda-empty')), findsNothing);
    expect(find.text('Nothing on this day'), findsNothing);
    expect(find.text('No events'), findsNothing);

    // Once the range is built and both streams emitted, the empty state is
    // final and may render.
    await repo.rebuildWindow(
      windowStartUtc: _emptyMonth.fromUtc,
      windowEndUtc: _emptyMonth.toUtc,
    );
    container
        .read(calendarBuiltRangeProvider.notifier)
        .markBuilt(_emptyMonth.cacheRange);
    await _pumpTwice(tester);
    await _revealAgenda(tester);

    expect(find.byKey(const Key('month-agenda-loading')), findsNothing);
    expect(find.byKey(const Key('month-agenda-empty')), findsOneWidget);

    await _tearDown(tester, db);
  });

  testWidgets('month shows an error banner and retry when occurrences fail', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpMonth(
      tester,
      db,
      CalendarWindow(anchor: _rangeA.anchor, view: CalendarViewKind.month),
      failOccurrences: true,
    );

    expect(find.byType(CalendarErrorBanner), findsOneWidget);
    expect(find.text('Could not load calendar.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await _pumpTwice(tester);
    expect(find.text('Could not load calendar.'), findsOneWidget);

    await _revealAgenda(tester);
    expect(find.byKey(const Key('month-agenda-empty')), findsNothing);
    expect(find.text('No events'), findsNothing);

    await _tearDown(tester, db);
  });

  testWidgets(
    'timeline shows an error banner and retry when occurrences fail',
    (WidgetTester tester) async {
      final db = _db();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            calendarStateProvider.overrideWith(() => _FixedWindow(_rangeA)),
            _failingOccurrences,
          ],
          child: const MaterialApp(home: Scaffold(body: _TimelineHost())),
        ),
      );
      await _pumpTwice(tester);

      expect(find.byType(CalendarErrorBanner), findsOneWidget);
      expect(find.text('Could not load calendar.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await _pumpTwice(tester);
      expect(find.text('Could not load calendar.'), findsOneWidget);

      await _tearDown(tester, db);
    },
  );

  testWidgets('year does not show final counts while the range loads', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          calendarStateProvider.overrideWith(
            () => _FixedWindow(
              CalendarWindow(
                anchor: DateTime(2027, 6, 1),
                view: CalendarViewKind.year,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: YearView())),
      ),
    );
    await _pumpTwice(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(YearView)),
    );

    // Switching to an unbuilt year must not render final zero counts.
    container
        .read(calendarStateProvider.notifier)
        .restore(CalendarViewKind.year, DateTime(2028, 6, 1));
    await _pumpTwice(tester);

    expect(find.textContaining('Events:'), findsNothing);
    expect(find.textContaining(RegExp(r'\n0')), findsNothing);
    expect(find.textContaining('\n...'), findsWidgets);

    await _tearDown(tester, db);
  });
}
