import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/core/time/time.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/domain/habits/date_key.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/calendar/presentation/timeline/timeline_chrome.dart';
import 'package:ephemeron/features/calendar/presentation/timeline/timeline_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _seed(
  AppDatabase db, {
  String? tzId,
  String calendarName = 'c',
  String? googleAccount,
  bool readOnly = false,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: 'cal1',
          name: calendarName,
          googleAccount: Value(googleAccount),
          readOnly: Value(readOnly),
          createdAt: now,
          updatedAt: now,
        ),
      );
  final day = DateTime.now();
  final start = DateTime(day.year, day.month, day.day, 10).toUtc();
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: 'e1',
          calendarId: 'cal1',
          title: const Value('Standup'),
          startUtc: Value(start.millisecondsSinceEpoch),
          endUtc: Value(
            start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
          ),
          tzId: Value(tzId),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _seedAllDay(
  AppDatabase db, {
  String id = 'a1',
  String title = 'Holiday',
  required DateTime day,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: id,
          calendarId: 'cal1',
          title: Value(title),
          isAllDay: const Value(true),
          startDate: Value(dateKey(day)),
          endDate: Value(dateKey(day.add(const Duration(days: 1)))),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _seedTimedEvent(
  AppDatabase db, {
  required String id,
  required String title,
  required DateTime start,
  required Duration duration,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: id,
          calendarId: 'cal1',
          title: Value(title),
          startUtc: Value(start.toUtc().millisecondsSinceEpoch),
          endUtc: Value(start.add(duration).toUtc().millisecondsSinceEpoch),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

CalendarWindow _window(DateTime anchor, int dayCount) => CalendarWindow(
  anchor: anchor,
  view: dayCount == 1 ? CalendarViewKind.day : CalendarViewKind.multiDay,
  dayCount: dayCount,
);

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  DateTime anchor,
  int dayCount, {
  double textScale = 1,
}) async {
  final window = _window(anchor, dayCount);
  await OccurrenceRepository(
    db,
  ).rebuildWindow(windowStartUtc: window.fromUtc, windowEndUtc: window.toUtc);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        calendarStateProvider.overrideWith(() => _FixedWindow(window)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: TimelineView(anchor: anchor, dayCount: dayCount),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Mirrors widget_test.dart: close the db and unmount inside the test so
/// Drift's stream-close timer fires before the pending-timer check.
Future<void> _tearDown(WidgetTester tester, AppDatabase db) async {
  await db.close();
  await tester.pumpWidget(Container());
  await tester.pump();
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

/// Vertical distance between two adjacent hour labels.
double _hourGap(WidgetTester tester) {
  final a = tester.getTopLeft(find.text('00:00'));
  final b = tester.getTopLeft(find.text('01:00'));
  return b.dy - a.dy;
}

Future<void> _pressZoomIn(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.equal);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.equal);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> _pressZoomOut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.minus);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.minus);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// Creates a task directly in the DB so the occurrence cache picks it up.
Future<String> _seedTask(
  AppDatabase db, {
  required String title,
  String? parentId,
  String? plannedStart,
  String? plannedEnd,
  String? dueDate,
  int? dueTime,
  String? plannedDate,
  String? rrule,
}) => TaskRepository(db).createTask(
  title: title,
  parentId: parentId,
  plannedStart: plannedStart,
  plannedEnd: plannedEnd,
  dueDate: dueDate,
  dueTime: dueTime,
  plannedDate: plannedDate,
  rrule: rrule,
);

Future<Task> _taskById(AppDatabase db, String id) =>
    (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();

/// Long-presses [finder] until the drag recognizer starts, moves by [dx]/[dy]
/// logical pixels, then releases and settles persistence.
Future<void> _dragBlock(
  WidgetTester tester,
  Finder finder,
  double dy, {
  double dx = 0,
}) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await tester.pump(const Duration(milliseconds: 700));
  await gesture.moveBy(Offset(dx, dy));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
  await tester.pump();
  // Drift stream/isolate work completes on the real event loop, which
  // pumpAndSettle alone does not drive. Yield to it without wall-clock sleeps.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('rebuild tolerates non-IANA tz abbreviations', () async {
    final db = _db();
    addTearDown(db.close);
    await _seed(db, tzId: '-03');
    final repo = OccurrenceRepository(db);
    final anchor = DateTime.now();
    final window = _window(anchor, 1);
    final n = await repo.rebuildWindow(
      windowStartUtc: window.fromUtc,
      windowEndUtc: window.toUtc,
    );
    expect(n, 1);
  });

  testWidgets('day view shows hours, header and event', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _seed(db);
    final anchor = DateTime.now();
    await _pump(tester, db, anchor, 1);

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
    expect(find.text('${anchor.day}'), findsOneWidget);
    expect(find.text('Standup'), findsOneWidget);

    // Tapping the event opens details instead of the create sheet.
    await tester.ensureVisible(find.text('Standup'));
    await tester.pump();
    await tester.tap(find.text('Standup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Edit'), findsOneWidget);
    await _tearDown(tester, db);
  });

  testWidgets('zero all-day items still offer an all-day create target', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _seed(db);
    final anchor = DateTime.now();
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    await _pump(tester, db, anchor, 1);

    expect(find.byType(TimelineAllDayStrip), findsOneWidget);
    expect(tester.getSize(find.byType(TimelineAllDayStrip)).height, 32);
    await tester.tap(find.byKey(Key('timeline-all-day-${dateKey(day)}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Create'), findsOneWidget);
    final allDay = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'All day'),
    );
    expect(allDay.value, isTrue);
    final ctx = tester.element(find.text('All day'));
    expect(find.text(DeviceDateFormat.date(ctx, day)), findsNWidgets(2));
    await _tearDown(tester, db);
  });

  testWidgets('tapping an existing all-day chip opens its details', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _seed(db);
    final anchor = DateTime.now();
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    await _seedAllDay(db, day: day);
    await _pump(tester, db, anchor, 1);

    await tester.tap(find.text('Holiday'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Create'), findsNothing);
    await _tearDown(tester, db);
  });

  testWidgets('timed blocks show the cached calendar source label', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _db();
    await _seed(db, calendarName: 'Work', googleAccount: 'g@example.com');
    await _pump(tester, db, DateTime.now(), 1);

    expect(find.textContaining('Work - g@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tearDown(tester, db);
  });

  testWidgets('source label stays readable at 320dp and large text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _db();
    await _seed(
      db,
      calendarName: 'A very long calendar name',
      googleAccount: 'a.long.account@example.com',
    );
    await _pump(tester, db, DateTime.now(), 1, textScale: 2);
    await tester.pump();

    expect(tester.takeException(), isNull);
    await _tearDown(tester, db);
  });

  testWidgets('tall event blocks allow more title lines than short blocks', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _db();
    await _seed(db);
    final day = DateTime.now();
    await _seedTimedEvent(
      db,
      id: 'short',
      title: 'Short half hour block',
      start: DateTime(day.year, day.month, day.day, 9),
      duration: const Duration(minutes: 30),
    );
    await _seedTimedEvent(
      db,
      id: 'tall',
      title: 'Long four hour block',
      start: DateTime(day.year, day.month, day.day, 12),
      duration: const Duration(hours: 4),
    );
    await _pump(tester, db, DateTime.now(), 1);
    await tester.pump();

    Text titleText(String prefix) => tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere(
          (text) =>
              (text.data ?? text.textSpan?.toPlainText())?.startsWith(prefix) ??
              false,
        );

    final short = titleText('Short half hour block');
    final tall = titleText('Long four hour block');
    expect(short.maxLines, 1);
    expect(tall.maxLines, greaterThan(3));
    await _tearDown(tester, db);
  });

  testWidgets('habit markers fit a 320dp timeline strip', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _db();
    final repo = HabitRepository(db);
    await repo.createHabit(
      name: 'A long habit name',
      frequency: 'daily',
      startDate: '2020-01-01',
    );
    await _seed(db);
    await _pump(tester, db, DateTime.now(), 1);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('A long habit name'), findsWidgets);
    expect(tester.takeException(), null);
    await _tearDown(tester, db);
  });

  testWidgets('timeline strip caps habits and shows overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _db();
    final repo = HabitRepository(db);
    for (var i = 1; i <= 5; i++) {
      await repo.createHabit(
        name: 'Habit $i',
        frequency: 'daily',
        startDate: '2020-01-01',
      );
    }
    await _seed(db);
    await _pump(tester, db, DateTime.now(), 1);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('+2 habits'), findsWidgets);
    expect(find.text('Habit 4'), findsNothing);
    expect(find.text('Habit 5'), findsNothing);
    expect(tester.takeException(), null);
    await _tearDown(tester, db);
  });

  testWidgets('timed habits use the hour grid and untimed stay all-day', (
    WidgetTester tester,
  ) async {
    final db = _db();
    final repo = HabitRepository(db);
    final timedId = await repo.createHabit(
      name: 'Timed habit',
      frequency: 'daily',
      startDate: '2020-01-01',
      reminderTime: '09:30',
      goalAmount: 4,
      unit: 'pages',
    );
    final allDayId = await repo.createHabit(
      name: 'All-day habit',
      frequency: 'daily',
      startDate: '2020-01-01',
    );
    final today = DateTime.now();
    await _seed(db);
    await _pump(tester, db, today, 1);
    await tester.pump(const Duration(milliseconds: 100));

    final dayKey = habitDateKey(today);
    final block = find.byKey(ValueKey('timeline-habit-$timedId-$dayKey'));
    expect(block, findsOneWidget);
    expect(
      find.descendant(of: block, matching: find.textContaining('Timed habit')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('timeline-habit-$allDayId-$dayKey')),
      findsNothing,
    );
    final allDayStrip = find.byType(TimelineAllDayStrip);
    expect(
      find.descendant(of: allDayStrip, matching: find.text('All-day habit')),
      findsWidgets,
    );
    expect(
      find.descendant(of: allDayStrip, matching: find.text('Timed habit')),
      findsNothing,
    );

    final hourHeight =
        tester.getTopLeft(find.text('10:00')).dy -
        tester.getTopLeft(find.text('09:00')).dy;
    expect(
      tester.getTopLeft(block).dy,
      moreOrLessEquals(
        tester.getTopLeft(find.text('09:00')).dy + 7 + hourHeight * 0.5,
        epsilon: 2,
      ),
    );
    await _tearDown(tester, db);
  });

  testWidgets('multi-day view shows all days and scrolls', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _seed(db);
    final anchor = DateTime.now();
    await _pump(tester, db, anchor, 3);

    for (var i = 0; i < 3; i++) {
      final d = DateTime(
        anchor.year,
        anchor.month,
        anchor.day,
      ).add(Duration(days: i));
      expect(find.text('${d.day}'), findsWidgets);
    }
    expect(find.text('Standup'), findsOneWidget);

    final scroller = find.byType(SingleChildScrollView);
    expect(scroller, findsOneWidget);
    await tester.drag(scroller, const Offset(0, -300));
    await tester.pump();
    // Still renders after scrolling (hours gutter scrolls in sync).
    expect(find.text('Standup', skipOffstage: false), findsOneWidget);
    expect(find.text('00:00', skipOffstage: false), findsOneWidget);
    await _tearDown(tester, db);
  });

  testWidgets('5-day multi-day view shows all five day headers', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _seed(db);
    final anchor = DateTime.now();
    await _pump(tester, db, anchor, 5);

    for (var i = 0; i < 5; i++) {
      final d = DateTime(
        anchor.year,
        anchor.month,
        anchor.day,
      ).add(Duration(days: i));
      expect(find.text('${d.day}'), findsWidgets);
    }
    expect(find.text('Standup'), findsOneWidget);

    await _tearDown(tester, db);
  });

  testWidgets(
    'swipe snaps across several days and keeps the hour gutter fixed',
    (WidgetTester tester) async {
      final db = _db();
      final anchor = DateTime(2027, 3, 1); // Monday
      final window = _window(anchor, 3);
      await OccurrenceRepository(db).rebuildWindow(
        windowStartUtc: window.fromUtc,
        windowEndUtc: window.toUtc,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            calendarStateProvider.overrideWith(() => _FixedWindow(window)),
          ],
          child: const MaterialApp(home: Scaffold(body: _TimelineHost())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final dayWidth =
          (tester.getSize(find.byType(TimelineView)).width - 48) / 3;
      final gutterBefore = tester.getTopLeft(find.text('00:00')).dx;
      final firstDayBefore = tester.getTopLeft(find.text('1')).dx;

      await tester.timedDrag(
        find.byType(TimelineView),
        Offset(-dayWidth * 1.8, 0),
        const Duration(milliseconds: 2000),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(_TimelineHost)),
      );
      expect(
        container.read(calendarStateProvider).anchor,
        DateTime(2027, 3, 3),
      );
      expect(
        tester.getTopLeft(find.text('00:00')).dx,
        moreOrLessEquals(gutterBefore),
      );
      expect(
        tester.getTopLeft(find.text('1')).dx,
        moreOrLessEquals(firstDayBefore - dayWidth * 2),
      );
      // The swipe swaps the watched occurrence window, so unmount first and
      // let the cancelled Drift stream settle before closing the database.
      await tester.pumpWidget(Container());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => db.close());
    },
  );

  testWidgets('keyboard Ctrl+= and Ctrl+- zoom the timeline', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _seed(db);
    await _pump(tester, db, DateTime.now(), 1);

    expect(_hourGap(tester), moreOrLessEquals(32.23529411764707));

    await _pressZoomIn(tester);
    expect(_hourGap(tester), moreOrLessEquals(32.23529411764707 * 1.25));

    await _pressZoomOut(tester);
    expect(_hourGap(tester), moreOrLessEquals(32.23529411764707));
    await _tearDown(tester, db);
  });

  testWidgets('pinch zooms the timeline', (WidgetTester tester) async {
    final db = _db();
    await _seed(db);
    await _pump(tester, db, DateTime.now(), 1);

    final before = _hourGap(tester);
    final center = tester.getCenter(find.byType(SingleChildScrollView));
    final g1 = await tester.startGesture(center + const Offset(-40, 0));
    await tester.pump();
    final g2 = await tester.startGesture(center + const Offset(40, 0));
    await tester.pump();
    await g1.moveTo(center + const Offset(-90, 0));
    await g2.moveTo(center + const Offset(90, 0));
    await tester.pump();
    expect(_hourGap(tester), greaterThan(before + 1));
    await g1.up();
    await g2.up();
    await _tearDown(tester, db);
  });

  testWidgets('read-only event drag is blocked and enqueues nothing', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _seed(db, readOnly: true);
    await _pump(tester, db, DateTime.now(), 1);
    final before = await (db.select(
      db.events,
    )..where((e) => e.id.equals('e1'))).getSingle();
    final target = find.text('Standup');
    await tester.ensureVisible(target);
    await tester.pump();

    final g = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveBy(const Offset(0, 80));
    await tester.pump(const Duration(milliseconds: 100));
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Calendar is read-only. Event not moved.'),
      findsOneWidget,
    );
    expect(await db.select(db.outbox).get(), isEmpty);
    final after = await (db.select(
      db.events,
    )..where((e) => e.id.equals('e1'))).getSingle();
    expect(after.startUtc, before.startUtc);
    await _tearDown(tester, db);
  });

  testWidgets(
    'dragging a timed task snaps 15 minutes and persists planned times',
    (WidgetTester tester) async {
      final db = _db();
      final day = DateTime(2027, 3, 1);
      final id = await _seedTask(
        db,
        title: 'Focus block',
        plannedStart: '2027-03-01T10:00',
        plannedEnd: '2027-03-01T11:00',
        plannedDate: '2027-03-01',
      );
      await _pump(tester, db, day, 1);

      // 16 minutes of travel must snap down to the nearest 15-minute slot.
      final dy = _hourGap(tester) * 16 / 60;
      await _dragBlock(tester, find.text('Focus block'), dy);

      final task = await _taskById(db, id);
      expect(task.plannedStart, '2027-03-01T10:15');
      expect(task.plannedEnd, '2027-03-01T11:15');
      expect(task.plannedDate, '2027-03-01');
      expect(task.dueDate, isNull);
      expect(find.text('Task moved'), findsOneWidget);
      await _tearDown(tester, db);
    },
  );

  testWidgets('dragging a due-time task persists snapped due date and time', (
    WidgetTester tester,
  ) async {
    final db = _db();
    final day = DateTime(2027, 3, 1);
    final id = await _seedTask(
      db,
      title: 'Due task',
      dueDate: '2027-03-01',
      dueTime: 10 * 60,
    );
    await _pump(tester, db, day, 1);

    final dy = _hourGap(tester) / 4; // exactly 15 minutes
    await _dragBlock(tester, find.text('Due task'), dy);

    final task = await _taskById(db, id);
    expect(task.dueDate, '2027-03-01');
    expect(task.dueTime, 10 * 60 + 15);
    expect(task.plannedStart, isNull);
    expect(task.plannedDate, isNull);
    await _tearDown(tester, db);
  });

  testWidgets('dragging a timed subtask moves it via by-id lookup', (
    WidgetTester tester,
  ) async {
    final db = _db();
    final day = DateTime(2027, 3, 1);
    final parent = await _seedTask(db, title: 'Parent');
    final sub = await _seedTask(
      db,
      title: 'Sub task',
      parentId: parent,
      plannedStart: '2027-03-01T10:00',
      plannedEnd: '2027-03-01T11:00',
    );
    await _pump(tester, db, day, 1);

    // watchOpen() excludes subtasks, so the drag must fall back to a direct
    // by-id lookup for the 15-minute move to be persisted.
    await _dragBlock(tester, find.text('Sub task'), _hourGap(tester) / 4);

    expect(find.text('Task moved'), findsOneWidget);
    final task = await _taskById(db, sub);
    expect(task.plannedStart, '2027-03-01T10:15');
    expect(task.plannedEnd, '2027-03-01T11:15');
    expect(task.parentId, parent);
    await _tearDown(tester, db);
  });

  testWidgets(
    'dragging a recurring task is declined without corrupting series',
    (WidgetTester tester) async {
      final db = _db();
      final day = DateTime(2027, 3, 1);
      final id = await _seedTask(
        db,
        title: 'Recurring block',
        plannedStart: '2027-03-01T10:00',
        plannedEnd: '2027-03-01T11:00',
        rrule: 'FREQ=DAILY',
      );
      await _pump(tester, db, day, 1);

      await _dragBlock(
        tester,
        find.text('Recurring block').first,
        _hourGap(tester) / 4,
      );

      expect(
        find.text('Recurring tasks cannot be moved by dragging'),
        findsOneWidget,
      );
      final task = await _taskById(db, id);
      expect(task.plannedStart, '2027-03-01T10:00');
      expect(task.plannedEnd, '2027-03-01T11:00');
      expect(task.rrule, 'FREQ=DAILY');
      await _tearDown(tester, db);
    },
  );

  testWidgets('dragging a timed task across days preserves wall-clock time', (
    WidgetTester tester,
  ) async {
    final db = _db();
    final day = DateTime(2027, 3, 1);
    final id = await _seedTask(
      db,
      title: 'Cross-day block',
      plannedStart: '2027-03-01T10:00',
      plannedEnd: '2027-03-01T11:00',
    );
    await _pump(tester, db, day, 3);

    final dayWidth =
        (tester.getSize(find.byType(SingleChildScrollView)).width - 48) / 3;
    await _dragBlock(tester, find.text('Cross-day block'), 0, dx: dayWidth);

    final task = await _taskById(db, id);
    expect(task.plannedStart, '2027-03-02T10:00');
    expect(task.plannedEnd, '2027-03-02T11:00');
    await _tearDown(tester, db);
  });

  testWidgets(
    'dragging a due-time task across days preserves wall-clock time',
    (WidgetTester tester) async {
      final db = _db();
      final day = DateTime(2027, 3, 1);
      final id = await _seedTask(
        db,
        title: 'Cross-day due',
        dueDate: '2027-03-01',
        dueTime: 10 * 60,
      );
      await _pump(tester, db, day, 3);

      final dayWidth =
          (tester.getSize(find.byType(SingleChildScrollView)).width - 48) / 3;
      await _dragBlock(tester, find.text('Cross-day due'), 0, dx: dayWidth);

      final task = await _taskById(db, id);
      expect(task.dueDate, '2027-03-02');
      expect(task.dueTime, 10 * 60);
      expect(task.plannedDate, isNull);
      await _tearDown(tester, db);
    },
  );

  testWidgets('dragging a plain event still moves it', (
    WidgetTester tester,
  ) async {
    final db = _db();
    await _seed(db);
    final anchor = DateTime.now();
    await _pump(tester, db, anchor, 1);
    final before = await (db.select(
      db.events,
    )..where((e) => e.id.equals('e1'))).getSingle();

    await _dragBlock(tester, find.text('Standup'), _hourGap(tester));

    expect(find.text('Event moved'), findsOneWidget);
    final after = await (db.select(
      db.events,
    )..where((e) => e.id.equals('e1'))).getSingle();
    expect(
      after.startUtc,
      before.startUtc! + const Duration(hours: 1).inMilliseconds,
    );
    expect(
      after.endUtc,
      before.endUtc! + const Duration(hours: 1).inMilliseconds,
    );
    await _tearDown(tester, db);
  });
}
