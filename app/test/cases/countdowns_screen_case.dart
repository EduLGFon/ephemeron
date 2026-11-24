import 'package:ephemeron/core/db/db_provider.dart';

import 'package:ephemeron/core/design/components/rows.dart';

import 'package:ephemeron/data/drift/app_database.dart';

import 'package:ephemeron/data/repositories/countdown_repository.dart';

import 'package:ephemeron/features/countdowns/presentation/countdowns_screen.dart';

import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';

import '../support/test_fixtures.dart';

late AppDatabase db;

void main() {
  setUpAll(() {
    db = newTestDb();
  });
  setUp(() => resetTestDb(db));
  tearDownAll(() async {
    await db.close();
  });
  testWidgets('countdown appears in upcoming', (WidgetTester tester) async {
    final repo = CountdownRepository(db);
    final nextYear = DateTime.now().year + 1;
    await repo.createCountdown(title: 'Trip', targetDate: '$nextYear-06-01');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CountdownsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.byType(AppCountdownCard), findsOneWidget);
    // Close the db and unmount inside the test body so Drift's
    // stream-close timer fires before the pending-timer check.
    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('countdowns group upcoming, passed and no-date', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CountdownRepository(db);
    final nextYear = DateTime.now().year + 1;
    final lastYear = DateTime.now().year - 1;
    await repo.createCountdown(title: 'Trip', targetDate: '$nextYear-06-01');
    await repo.createCountdown(title: 'Past', targetDate: '$lastYear-06-01');
    await repo.createCountdown(title: 'Someday');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CountdownsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
    expect(find.text('No date'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Someday'), findsOneWidget);
    expect(find.byType(AppCountdownCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('delete offers undo and keeps the countdown', (
    WidgetTester tester,
  ) async {
    final repo = CountdownRepository(db);
    final nextYear = DateTime.now().year + 1;
    await repo.createCountdown(title: 'Trip', targetDate: '$nextYear-06-01');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CountdownsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('More options'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(find.text('Countdown deleted.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    final rows = await (db.select(db.countdowns)).get();
    expect(rows.map((row) => row.title), contains('Trip'));

    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });
}
