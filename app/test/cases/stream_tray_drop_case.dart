// Tray drag-to-schedule on the Stream day canvas.
//
// StreamDayBody always wires the drop handler, so these tests mount it beside
// a real TrayChip and drive the long-press drag end to end. The tray actions
// run for real against a fake gateway, which pins the scheduled fields and the
// occurrence-cache rebuild to the drop time.
import 'package:ephemeron/data/drift/app_database.dart' show Task, TaskList;
import 'package:ephemeron/features/stream/application/stream_ambient.dart'
    show streamCountdownLandmarkItemsProvider, streamHabitGutterItemsProvider;
import 'package:ephemeron/features/stream/application/stream_day_providers.dart';
import 'package:ephemeron/features/stream/application/stream_tray_actions.dart';
import 'package:ephemeron/features/stream/presentation/countdowns/countdown_landmark_item.dart'
    show CountdownLandmarkItem;
import 'package:ephemeron/features/stream/presentation/day/day_canvas.dart';
import 'package:ephemeron/features/stream/presentation/gestures/tray_drop_target.dart';
import 'package:ephemeron/features/stream/presentation/habits/habit_gutter_item.dart'
    show HabitGutterItem;
import 'package:ephemeron/features/stream/presentation/stream_day_body.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_chip.dart';
import 'package:ephemeron/features/stream/presentation/tray/tray_item.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart'
    show openTasksProvider, taskListsProvider;
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_fixtures.dart';

const TrayItem _item = TrayItem(
  id: 't1',
  title: 'Unscheduled task',
  listId: 'l1',
  listName: 'Work',
  colorArgb: 0xFF336699,
);

Task _task() => const Task(
  id: 't1',
  listId: 'l1',
  title: 'Unscheduled task',
  priority: 0,
  pinned: false,
  wontDo: false,
  sortOrder: 0,
  createdAt: 0,
  updatedAt: 0,
  dirty: false,
);

class _Update {
  const _Update({
    required this.taskId,
    required this.plannedStart,
    required this.plannedEnd,
    required this.plannedDate,
    required this.dueTime,
  });

  final String taskId;
  final String? plannedStart;
  final String? plannedEnd;
  final String? plannedDate;
  final int? dueTime;
}

class _FakeGateway implements StreamTrayGateway {
  final updates = <_Update>[];
  final rebuiltDays = <DateTime>[];

  @override
  Future<void> updateTask(
    String taskId, {
    required String? plannedStart,
    required String? plannedEnd,
    required String? plannedDate,
    int? dueTime,
  }) async {
    updates.add(
      _Update(
        taskId: taskId,
        plannedStart: plannedStart,
        plannedEnd: plannedEnd,
        plannedDate: plannedDate,
        dueTime: dueTime,
      ),
    );
  }

  @override
  Future<void> rebuildDay(DateTime day) async => rebuiltDays.add(day);
}

Widget _app({
  required _FakeGateway gateway,
  VoidCallback? onTap,
  TrayItem item = _item,
}) {
  return ProviderScope(
    overrides: [
      streamMarksForDayProvider.overrideWith(
        (ref, key) async => const StreamDayMarks(marks: [], skippedCount: 0),
      ),
      streamHabitGutterItemsProvider.overrideWith(
        (ref, range) => Stream.value(const <HabitGutterItem>[]),
      ),
      streamCountdownLandmarkItemsProvider.overrideWith(
        (ref) => Stream.value(const <CountdownLandmarkItem>[]),
      ),
      streamTrayGatewayProvider.overrideWithValue(gateway),
      openTasksProvider(null)
          .overrideWith((ref) => Stream.value(<Task>[_task()])),
      taskListsProvider.overrideWith((ref) => Stream.value(const <TaskList>[])),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            TrayChip(item: item, onTap: onTap ?? () {}),
            Expanded(
              child: StreamDayBody(
                date: DateTime(2026, 11, 17),
                now: DateTime(2026, 11, 17, 10),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pumpApp(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('long-press drag onto the canvas schedules at the drop time', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _pumpApp(tester, _app(gateway: gateway));

    expect(find.byType(TrayDropTarget), findsOneWidget);
    final viewport = tester.widget<DayCanvas>(find.byType(DayCanvas)).viewport;
    final rect = tester.getRect(find.byType(DayCanvas));
    final dropTime = DateTime(2026, 11, 17, 9, 45);
    final drop = Offset(
      rect.center.dx,
      rect.top + viewport.timeToPx(dropTime.millisecondsSinceEpoch),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TrayChip)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(drop);
    await tester.pump();
    await gesture.up();
    await settle(tester);

    expect(gateway.updates, hasLength(1));
    final update = gateway.updates.single;
    expect(update.taskId, 't1');
    expect(update.plannedStart, '2026-11-17T09:45');
    expect(update.plannedEnd, '2026-11-17T10:15');
    expect(update.plannedDate, isNull);
    expect(update.dueTime, 9 * 60 + 45);
    expect(gateway.rebuiltDays, [DateTime(2026, 11, 17)]);
  });

  testWidgets('tap still fires onTap and never schedules', (tester) async {
    final gateway = _FakeGateway();
    var taps = 0;
    await _pumpApp(tester, _app(gateway: gateway, onTap: () => taps++));

    await tester.tap(find.byType(TrayChip));
    await tester.pump();

    expect(taps, 1);
    expect(gateway.updates, isEmpty);
  });

  testWidgets('canvas pan still scrolls and never schedules', (tester) async {
    final gateway = _FakeGateway();
    await _pumpApp(tester, _app(gateway: gateway));

    final viewport = tester.widget<DayCanvas>(find.byType(DayCanvas)).viewport;
    final before = viewport.offsetPx;
    await tester.drag(find.byType(DayCanvas), const Offset(0, -120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(viewport.offsetPx, isNot(before));
    expect(gateway.updates, isEmpty);
    expect(gateway.rebuiltDays, isEmpty);
  });

  testWidgets('pinch still zooms and never schedules', (tester) async {
    final gateway = _FakeGateway();
    await _pumpApp(tester, _app(gateway: gateway));

    expect(find.byType(TrayDropTarget), findsOneWidget);
    final viewport = tester.widget<DayCanvas>(find.byType(DayCanvas)).viewport;
    final before = viewport.minutesPerPixel;
    final center = tester.getCenter(find.byType(DayCanvas));
    final first = await tester.startGesture(center + const Offset(-40, 0));
    final second = await tester.startGesture(center + const Offset(40, 0));
    await tester.pump();
    await first.moveBy(const Offset(0, -30));
    await second.moveBy(const Offset(0, 30));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(viewport.minutesPerPixel, isNot(before));
    expect(gateway.updates, isEmpty);
  });

  testWidgets('chip at 320 dp and 2.0 scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                child: TrayChip(
                  item: const TrayItem(
                    id: 'long',
                    title: 'A very long task title that should not overflow',
                    listId: 'l1',
                    listName: 'Work',
                    colorArgb: 0xFF336699,
                  ),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
