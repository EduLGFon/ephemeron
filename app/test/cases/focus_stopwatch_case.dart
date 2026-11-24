import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/design/components/visuals.dart';
import 'package:ephemeron/core/ids/ids.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/focus_repository.dart';
import 'package:ephemeron/features/focus/presentation/focus_screen.dart';
import 'package:ephemeron/features/focus/presentation/focus_strings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fixtures.dart';

/// Minimal widget tree around the clock face so the goal ring value and dial
/// paint layer can be inspected without booting the whole screen/providers.
Widget _face(ValueNotifier<int> now, FocusSession session) {
  return MaterialApp(
    home: FocusTimeFace(
      now: now,
      session: session,
      strings: const FocusStrings(Locale('en')),
    ),
  );
}

FocusSession _session({
  required int startUtc,
  int? targetEndUtc,
  String phase = 'stopwatch',
}) {
  return FocusSession(
    id: 's',
    startUtc: startUtc,
    targetEndUtc: targetEndUtc,
    phase: phase,
    createdAt: startUtc,
    updatedAt: startUtc,
  );
}

double _ringValue(WidgetTester tester) =>
    tester.widget<AppProgressRing>(find.byType(AppProgressRing)).value;

void main() {
  late AppDatabase db;
  setUpAll(() => db = newTestDb());
  setUp(() => resetTestDb(db));
  tearDownAll(() => db.close());
  test('stopwatch start stores no target end and stopwatch phase', () async {
    final repo = FocusRepository(db);

    final id = await repo.startSession();

    final session = await repo.currentSession();
    expect(session?.id, id);
    expect(session?.phase, 'stopwatch');
    expect(session?.targetEndUtc, isNull);

    await repo.finishSession(id);
    expect(await repo.currentSession(), isNull);
  });

  testWidgets('stopwatch counts up and finishes from the screen', (
    WidgetTester tester,
  ) async {
    const alarms = MethodChannel('ephemeron/alarms');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(alarms, (call) async => null);
    // Handlers installed on the default messenger persist across widget tests
    // in this file, so reset before the next file runs.
    addTearDown(() => messenger.setMockMethodCallHandler(alarms, null));
    final repo = FocusRepository(db);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = newId();
    await db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: id,
            startUtc: now - const Duration(seconds: 125).inMilliseconds,
            phase: const Value('stopwatch'),
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

    expect(
      find.bySemanticsLabel(RegExp('Focus elapsed time: 02:')),
      findsOneWidget,
    );
    expect(find.textContaining('Time is up'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);

    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(await repo.currentSession(), isNull);
    final finished = await (db.select(
      db.focusSessions,
    )..where((f) => f.id.equals(id))).getSingle();
    expect(finished.endUtc, isNotNull);

    // Advance fake time so Drift's stream-close timer fires before
    // the pending-timer check; the shared db stays open for the file.
    await tester.pumpWidget(Container());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('stopwatch goal ring fills once per 60-minute cycle', (
    WidgetTester tester,
  ) async {
    const min = 60000;
    final now = ValueNotifier<int>(0);
    addTearDown(now.dispose);
    await tester.pumpWidget(_face(now, _session(startUtc: 0)));

    expect(_ringValue(tester), 0.0);

    now.value = 30 * min;
    await tester.pump();
    expect(_ringValue(tester), closeTo(0.5, 0.0001));

    // At the exact hour boundary the ring is full before the next cycle.
    now.value = 60 * min;
    await tester.pump();
    expect(_ringValue(tester), 1.0);

    now.value = 75 * min;
    await tester.pump();
    expect(_ringValue(tester), closeTo(0.25, 0.0001));
  });

  testWidgets('timed goal ring fills from empty to complete', (
    WidgetTester tester,
  ) async {
    const min = 60000;
    const start = 1000;
    const total = 20 * min;
    final now = ValueNotifier<int>(start);
    addTearDown(now.dispose);
    await tester.pumpWidget(
      _face(now, _session(startUtc: start, targetEndUtc: start + total)),
    );

    expect(_ringValue(tester), 0.0);

    now.value = start + 5 * min;
    await tester.pump();
    expect(_ringValue(tester), closeTo(0.25, 0.0001));

    now.value = start + 10 * min;
    await tester.pump();
    expect(_ringValue(tester), closeTo(0.5, 0.0001));

    now.value = start + total;
    await tester.pump();
    expect(_ringValue(tester), 1.0);

    // Past the target the value is clamped to a complete ring.
    now.value = start + total + min;
    await tester.pump();
    expect(_ringValue(tester), 1.0);
  });

  testWidgets('non-positive goal duration shows a full ring', (
    WidgetTester tester,
  ) async {
    final now = ValueNotifier<int>(5000);
    addTearDown(now.dispose);
    await tester.pumpWidget(
      _face(now, _session(startUtc: 5000, targetEndUtc: 4000)),
    );
    expect(_ringValue(tester), 1.0);
  });

  testWidgets('clock dial is a foreground painter over the goal ring', (
    WidgetTester tester,
  ) async {
    final now = ValueNotifier<int>(5 * 60000);
    addTearDown(now.dispose);
    await tester.pumpWidget(_face(now, _session(startUtc: 0)));

    final dials = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.foregroundPainter != null &&
          widget.foregroundPainter!.runtimeType.toString().contains(
            'ClockDialPainter',
          ),
    );
    expect(dials, findsOneWidget);
    final dial = tester.widget<CustomPaint>(dials);
    expect(
      dial.foregroundPainter!.runtimeType.toString(),
      contains('ClockDialPainter'),
    );
    // Ticks live only in the foreground layer; the ring keeps the background
    // painter slot, so nothing paints over the ticks after them.
    expect(dial.painter, isNull);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter != null,
      ),
      findsWidgets,
    );
  });
}
