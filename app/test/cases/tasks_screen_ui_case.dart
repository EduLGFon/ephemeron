// Tasks screen design coverage: list and smart-list chips, quick filters,
// completion undo, swipe actions, pending delete undo, empty state, custom
// drag mode and narrow-screen large-text layout.
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/design/components/app_chips.dart';
import 'package:ephemeron/core/design/components/visuals.dart';
import 'package:ephemeron/core/design/theme.dart';
import 'package:ephemeron/core/time/time.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/tasks/presentation/task_lists_screen.dart';
import 'package:ephemeron/features/tasks/presentation/tasks_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Widget _app(Widget home, {double textScale = 1}) {
  return MaterialApp(
    theme: EphemeronTheme.build(
      mode: 'light',
      platformBrightness: Brightness.light,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child ?? const SizedBox.shrink(),
    ),
    home: home,
  );
}

Future<void> _pumpTasks(
  WidgetTester tester,
  AppDatabase db, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: _app(const TasksScreen(), textScale: textScale),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

String? _rowSubtitle(WidgetTester tester, String taskId) {
  final texts = tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(ValueKey('task-$taskId')),
      matching: find.byType(Text),
    ),
  );
  return texts.length > 1 ? texts.elementAt(1).data : null;
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
}

Future<void> _swipe(WidgetTester tester, String taskId, double dx) async {
  final row = find.byKey(ValueKey<String>('task-dismiss-$taskId'));
  expect(row, findsOneWidget);
  await tester.drag(row, Offset(dx, 0));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'tasks.sort': 'due',
      'lists.sort': 'custom',
    });
  });

  testWidgets('list and smart-list chips filter rows and show counts', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      final work = await repo.createList('Work');
      final personal = await repo.createList('Personal');
      await repo.createTask(title: 'Work item', listId: work);
      await repo.createTask(title: 'Home item', listId: personal);
      await repo.createTask(title: 'Urgent item', listId: work, priority: 4);
      final urgent = await repo.createSmartList('Urgent', {
        'priorities': [4],
        'showCompleted': false,
      });
      await _pumpTasks(tester, db);

      expect(find.text('Work item'), findsOneWidget);
      expect(find.text('Home item'), findsOneWidget);
      expect(
        tester
            .widget<AppChip>(find.byKey(ValueKey('task-smart-$urgent')))
            .label,
        'Urgent (1)',
      );

      await tester.tap(find.byKey(ValueKey('task-list-$work')));
      await _settle(tester);
      expect(find.text('Work item'), findsOneWidget);
      expect(find.text('Urgent item'), findsOneWidget);
      expect(find.text('Home item'), findsNothing);
      expect(
        tester
            .widget<AppChip>(find.byKey(ValueKey('task-list-$work')))
            .selected,
        isTrue,
      );

      await tester.tap(find.byKey(ValueKey('task-smart-$urgent')));
      await _settle(tester);
      expect(find.text('Urgent item'), findsOneWidget);
      expect(find.text('Work item'), findsNothing);
      expect(
        tester
            .widget<AppChip>(find.byKey(ValueKey('task-list-$work')))
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<AppChip>(find.byKey(ValueKey('task-smart-$urgent')))
            .selected,
        isTrue,
      );
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('All, Today, Upcoming and Completed filters slice the list', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      await repo.createTask(
        title: 'Overdue task',
        dueDate: dateKey(DateTime.now().subtract(const Duration(days: 1))),
      );
      await repo.createTask(
        title: 'Today task',
        dueDate: dateKey(DateTime.now()),
      );
      await repo.createTask(
        title: 'Upcoming task',
        dueDate: dateKey(DateTime.now().add(const Duration(days: 2))),
      );
      final done = await repo.createTask(title: 'Completed task');
      await repo.completeTask(done);
      await _pumpTasks(tester, db);

      expect(find.text('Overdue task'), findsOneWidget);
      expect(find.text('Today task'), findsOneWidget);
      expect(find.text('Upcoming task'), findsOneWidget);
      expect(find.text('Completed task'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('task-filter-today')));
      await _settle(tester);
      expect(find.text('Overdue task'), findsOneWidget);
      expect(find.text('Today task'), findsOneWidget);
      expect(find.text('Upcoming task'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('task-filter-upcoming')));
      await _settle(tester);
      expect(find.text('Upcoming task'), findsOneWidget);
      expect(find.text('Today task'), findsNothing);
      expect(find.text('Overdue task'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('task-filter-completed')));
      await _settle(tester);
      expect(find.text('Completed task'), findsOneWidget);
      expect(find.text('Today task'), findsNothing);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets(
    'today shows time only and overdue shows a red date without a tag',
    (WidgetTester tester) async {
      final db = _db();
      try {
        final repo = TaskRepository(db);
        final todayId = await repo.createTask(
          title: 'Today timed',
          dueDate: dateKey(DateTime.now()),
          dueTime: 15 * 60 + 30,
        );
        final lateId = await repo.createTask(
          title: 'Late timed',
          dueDate: dateKey(DateTime.now().subtract(const Duration(days: 1))),
          dueTime: 9 * 60,
        );
        await _pumpTasks(tester, db);

        final todaySubtitle = _rowSubtitle(tester, todayId);
        expect(todaySubtitle, isNotNull);
        expect(todaySubtitle, isNot(contains('Due')));
        expect(todaySubtitle, contains('30'));

        final lateSubtitle = _rowSubtitle(tester, lateId);
        expect(lateSubtitle, contains('Due'));
        final lateRow = find.byKey(ValueKey('task-$lateId'));
        expect(
          find.descendant(of: lateRow, matching: find.text('Overdue')),
          findsNothing,
        );
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
        final error = Theme.of(tester.element(lateRow)).colorScheme.error;
        final lateTexts = tester.widgetList<Text>(
          find.descendant(of: lateRow, matching: find.byType(Text)),
        );
        expect(lateTexts.any((text) => text.style?.color == error), isTrue);
      } finally {
        await _dispose(tester, db);
      }
    },
  );

  testWidgets('checkbox completes a task and undo reopens it', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      final id = await repo.createTask(title: 'Undoable');
      await _pumpTasks(tester, db);

      await tester.tap(find.byType(AppCheckmark));
      await _settle(tester);

      expect(find.text('Completed "Undoable"'), findsOneWidget);
      expect(find.text('Priority'), findsNothing);
      var task = (await db.select(db.tasks).get()).single;
      expect(task.completedAt, isNotNull);

      await tester.tap(find.text('Undo'));
      await _settle(tester);

      task = (await db.select(db.tasks).get()).single;
      expect(task.completedAt, isNull);
      expect(find.text('Undoable'), findsOneWidget);
      expect(id, task.id);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('swiping right completes a task', (WidgetTester tester) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      final id = await repo.createTask(title: 'Swipe done');
      await _pumpTasks(tester, db);

      await _swipe(tester, id, 400);

      final task = (await db.select(db.tasks).get()).single;
      expect(task.completedAt, isNotNull);
      expect(find.text('Completed "Swipe done"'), findsOneWidget);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('swiping left reschedules with a 6 second undo', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      final today = dateKey(DateTime.now());
      final id = await repo.createTask(title: 'Move me', dueDate: today);
      await _pumpTasks(tester, db);

      await _swipe(tester, id, -400);
      expect(find.text('Reschedule or more'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);

      await tester.tap(find.text('Tomorrow'));
      await _settle(tester);
      var task = (await db.select(db.tasks).get()).single;
      expect(
        task.dueDate,
        dateKey(DateTime.now().add(const Duration(days: 1))),
      );

      await tester.tap(find.text('Undo'));
      await _settle(tester);
      task = (await db.select(db.tasks).get()).single;
      expect(task.dueDate, today);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('swiping left deletes through the pending buffer and undo', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      final id = await repo.createTask(title: 'Temp');
      await _pumpTasks(tester, db);

      await _swipe(tester, id, -400);
      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();

      final ops = await db.select(db.pendingOperations).get();
      expect(ops, hasLength(1));
      expect(ops.single.entity, 'task');
      expect(ops.single.entityId, id);
      expect(ops.single.op, 'delete');
      expect(find.text('Deleted "Temp"'), findsOneWidget);
      expect(find.text('Temp'), findsNothing);

      await tester.tap(find.text('Undo'));
      await _settle(tester);

      expect(await db.select(db.pendingOperations).get(), isEmpty);
      expect(find.text('Temp'), findsOneWidget);

      // Let the pending-operation timer fire with an empty queue so the test
      // does not leave a live timer behind.
      await tester.pump(const Duration(seconds: 7));
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('long press opens the task action sheet', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      await repo.createTask(title: 'Task one');
      await _pumpTasks(tester, db);

      await tester.longPress(find.text('Task one'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as concluded'), findsOneWidget);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('tapping a row opens the task editor', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      final repo = TaskRepository(db);
      await repo.createTask(title: 'Task two');
      await _pumpTasks(tester, db);

      await tester.tap(find.text('Task two'));
      await tester.pumpAndSettle();
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Pinned'), findsOneWidget);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('empty state offers add and list management', (
    WidgetTester tester,
  ) async {
    final db = _db();
    try {
      await _pumpTasks(tester, db);

      expect(find.text('No tasks here'), findsOneWidget);
      expect(find.text('Add a task'), findsOneWidget);
      expect(find.text('Manage lists'), findsOneWidget);

      await tester.tap(find.text('Manage lists'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TaskListsScreen), findsOneWidget);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('custom order shows drag handles only without search', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'tasks.sort': 'custom',
      'lists.sort': 'custom',
    });
    final db = _db();
    try {
      final repo = TaskRepository(db);
      final id = await repo.createTask(title: 'Alpha');
      await _pumpTasks(tester, db);
      await _settle(tester);

      final handle = find.byKey(ValueKey<String>('task-drag-$id'));
      expect(handle, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tasks-search')));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'Al');
      await _settle(tester);
      expect(handle, findsNothing);

      await tester.tap(find.byKey(const ValueKey('tasks-search')));
      await _settle(tester);
      expect(handle, findsOneWidget);
    } finally {
      await _dispose(tester, db);
    }
  });

  testWidgets('320dp at 200 percent text has no overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = _db();
    try {
      final repo = TaskRepository(db);
      final list = await repo.createList('Long list name for narrow layout');
      await repo.createTask(
        title: 'Overdue task with a very long name that should ellipsize',
        listId: list,
        dueDate: dateKey(DateTime.now().subtract(const Duration(days: 1))),
        priority: 4,
        pinned: true,
      );
      await repo.createTask(
        title: 'Today task',
        listId: list,
        dueDate: dateKey(DateTime.now()),
      );
      await repo.createTask(
        title: 'Future task',
        listId: list,
        dueDate: dateKey(DateTime.now().add(const Duration(days: 2))),
      );
      await _pumpTasks(tester, db, textScale: 2);

      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('tasks-search')));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    } finally {
      await _dispose(tester, db);
    }
  });
}
