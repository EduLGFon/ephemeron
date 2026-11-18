// Calendar page header: the title reads "Calendar", the current period sits
// below it, and the period controls fit a narrow page without overflowing.
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/design/components/app_headers.dart';
import 'package:ephemeron/core/design/components/sync_indicator.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/calendar/presentation/calendar_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

class _FixedWindow extends CalendarState {
  _FixedWindow(this.window);
  final CalendarWindow window;
  @override
  CalendarWindow build() => window;
}

final _anchor = DateTime(2026, 11, 4);

Future<void> _pumpHeader(
  WidgetTester tester,
  AppDatabase db, {
  Size size = const Size(400, 800),
}) async {
  final window = CalendarWindow(anchor: _anchor, view: CalendarViewKind.month);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        calendarStateProvider.overrideWith(() => _FixedWindow(window)),
      ],
      child: MaterialApp(
        // Material's default sparkle splash loads a Vulkan-only shader that
        // the Skia test backend cannot run; derive the test theme without it.
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const CalendarScreen(),
      ),
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

  testWidgets('header shows Calendar above the current period', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpHeader(tester, db);

    expect(find.byType(AppPageHeader), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    final period = DateFormat.yMMM('en_US').format(_anchor);
    final periodFinder = find.text(period);
    expect(periodFinder, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Calendar')).dy,
      lessThan(tester.getTopLeft(periodFinder).dy),
    );

    await _tearDown(tester, db);
  });

  testWidgets('header exposes the period, view, settings and sync controls', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpHeader(tester, db);

    expect(find.byTooltip('Today'), findsOneWidget);
    expect(find.byTooltip('Previous'), findsOneWidget);
    expect(find.byTooltip('Next'), findsOneWidget);
    expect(find.byKey(const Key('calendar-view-menu')), findsOneWidget);
    expect(find.byTooltip('Calendar settings'), findsOneWidget);
    expect(find.byType(AppSyncIndicator), findsOneWidget);

    await _tearDown(tester, db);
  });

  testWidgets('next moves a month view to the following month', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpHeader(tester, db);

    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    expect(
      find.text(DateFormat.yMMM('en_US').format(DateTime(2026, 12, 4))),
      findsOneWidget,
    );

    await _tearDown(tester, db);
  });

  testWidgets('header does not overflow a narrow page', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _pumpHeader(tester, db, size: const Size(320, 640));

    expect(find.byType(AppPageHeader), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tearDown(tester, db);
  });
}
