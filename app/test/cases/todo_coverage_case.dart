// Widget coverage for task-list and smart-list chip management, long-press
// drag reordering, and habit agenda rows with "Open habits" navigation.
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/calendar/presentation/agenda_view.dart';
import 'package:ephemeron/features/tasks/presentation/task_lists_screen.dart';
import 'package:ephemeron/features/tasks/presentation/tasks_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _pumpTasks(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: TasksScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
}

Finder _listChip(String name) => find.widgetWithText(ChoiceChip, name);

Finder _smartChip(String name) => find.ancestor(
  of: find.textContaining(name),
  matching: find.byType(ChoiceChip),
);

class _AgendaWindow extends CalendarState {
  @override
  CalendarWindow build() =>
      CalendarWindow(anchor: DateTime.now(), view: CalendarViewKind.agenda);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'tasks.sort': 'custom',
      'lists.sort': 'custom',
    });
  });

  testWidgets('long-pressing a list chip opens list management', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      final work = await repo.createList('Work');
      await repo.createTask(title: 'Draft', listId: work);
      await _pumpTasks(tester, db);

      await tester.longPress(_listChip('Work'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TaskListsScreen), findsOneWidget);
      expect(find.text('Manage lists'), findsOneWidget);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('tapping list and smart-list chips selects them', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      final work = await repo.createList('Work');
      await repo.createTask(title: 'Draft', listId: work);
      await repo.createSmartList('Important', {
        'priorities': [4],
        'showCompleted': false,
      });
      await _pumpTasks(tester, db);

      expect(tester.widget<ChoiceChip>(_listChip('Work')).selected, isFalse);
      await tester.tap(_listChip('Work'));
      await tester.pump();
      expect(tester.widget<ChoiceChip>(_listChip('Work')).selected, isTrue);
      expect(
        tester.widget<ChoiceChip>(_smartChip('Important')).selected,
        isFalse,
      );

      await tester.tap(_smartChip('Important'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<ChoiceChip>(_smartChip('Important')).selected,
        isTrue,
      );
      expect(tester.widget<ChoiceChip>(_listChip('Work')).selected, isFalse);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('desktop hover still shows the list chip tooltip', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      await repo.createList('Work');
      await _pumpTasks(tester, db);

      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: _listChip('Work'), matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, 'On this device');

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(_listChip('Work')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('On this device'), findsOneWidget);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('long-pressing a smart-list chip can delete it', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      await repo.createSmartList('Important', {
        'priorities': [4],
        'showCompleted': false,
      });
      await _pumpTasks(tester, db);

      expect(_smartChip('Important'), findsOneWidget);
      await tester.longPress(_smartChip('Important'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit smart list'), findsOneWidget);
      expect(find.text('Delete smart list'), findsOneWidget);

      await tester.tap(find.text('Delete smart list'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Important'), findsNothing);
      expect(await db.select(db.smartLists).get(), isEmpty);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('long-press drag reorders tasks and persists sortOrder', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = _db();
    try {
      final repo = TaskRepository(db);
      final list = await repo.createList('Work');
      final first = await repo.createTask(title: 'Alpha', listId: list);
      final second = await repo.createTask(title: 'Beta', listId: list);
      final third = await repo.createTask(title: 'Gamma', listId: list);
      await _pumpTasks(tester, db);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Alpha')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 140));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final orders = {
        for (final task in await db.select(db.tasks).get())
          task.id: task.sortOrder,
      };
      expect(orders.values.toSet(), {0, 1, 2});
      expect(orders[first], greaterThan(orders[second]!));
      expect(orders[third], isNotNull);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('long-press drag reorders task lists and persists sortOrder', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = _db();
    try {
      final repo = TaskRepository(db);
      final first = await repo.createList('Alpha list');
      final second = await repo.createList('Beta list');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: TaskListsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Alpha list')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 90));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final orders = {
        for (final list in await db.select(db.taskLists).get())
          list.id: list.sortOrder,
      };
      expect(orders[first], 1);
      expect(orders[second], 0);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('agenda shows habit rows and Open habits navigates', (
    WidgetTester tester,
  ) async {
    final db = _db();
    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (_, _) => const Scaffold(body: AgendaView()),
        ),
        GoRoute(
          path: '/tab3',
          builder: (_, _) => const Scaffold(body: Text('Habits tab')),
        ),
      ],
    );
    try {
      final repo = HabitRepository(db);
      final id = await repo.createHabit(
        name: 'Read',
        frequency: 'daily',
        startDate: '2020-01-01',
      );
      final today = DateTime.now();
      final todayKey =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            calendarStateProvider.overrideWith(_AgendaWindow.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final row = find.byKey(ValueKey('agenda-habit-$id-$todayKey'));
      expect(row, findsOneWidget);
      expect(find.text('Read'), findsWidgets);

      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mark as concluded'), findsOneWidget);
      expect(find.text('Open habits'), findsOneWidget);

      await tester.tap(find.text('Open habits'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Habits tab'), findsOneWidget);
      expect(find.text('Open habits'), findsNothing);
    } finally {
      await _dispose(tester, db);
      router.dispose();
    }
  });
}
