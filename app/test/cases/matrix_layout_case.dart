import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/tasks/presentation/matrix_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('quadrant card is taller than the unclassified tray', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    final now = DateTime.now();
    await repo.createTask(
      title: 'Do first task',
      priority: 3,
      dueDate: _date(now.add(const Duration(days: 1))),
    );
    await repo.createTask(title: 'Unclassified task');

    await _pumpMatrix(tester, db);
    final fieldHeight = tester
        .getSize(find.byKey(const ValueKey('matrix-field-doFirst')))
        .height;
    final trayHeight = tester
        .getSize(find.byKey(const ValueKey('matrix-unclassified')))
        .height;
    expect(fieldHeight, greaterThan(trayHeight));

    await _dispose(tester, db);
  });

  testWidgets('each field exposes a scrollbar key with many tasks', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    final now = DateTime.now();
    await repo.createTask(
      title: 'Do first task',
      priority: 3,
      dueDate: _date(now.add(const Duration(days: 1))),
    );
    await repo.createTask(
      title: 'Schedule task',
      priority: 3,
      dueDate: _date(now.add(const Duration(days: 30))),
    );
    await repo.createTask(
      title: 'Delegate task',
      priority: 1,
      dueDate: _date(now.add(const Duration(days: 1))),
    );
    await repo.createTask(
      title: 'Eliminate task',
      priority: 1,
      dueDate: _date(now.add(const Duration(days: 30))),
    );

    await _pumpMatrix(tester, db);

    for (final id in const ['doFirst', 'schedule', 'delegate', 'eliminate']) {
      expect(find.byKey(ValueKey('matrix-scrollbar-$id')), findsOneWidget);
    }

    await _dispose(tester, db);
  });

  testWidgets('320x480 renders the tray without overflow', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    for (var i = 0; i < 6; i++) {
      await repo.createTask(title: 'Task number $i', priority: i % 4);
    }

    await _pumpMatrix(tester, db);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('matrix-unclassified')), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('tray with many tasks stays compact and scrolls', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    for (var i = 0; i < 20; i++) {
      await repo.createTask(title: 'Unclassified $i');
    }

    await _pumpMatrix(tester, db);
    final trayHeight = tester
        .getSize(find.byKey(const ValueKey('matrix-unclassified')))
        .height;
    expect(trayHeight, lessThanOrEqualTo(140));
    expect(
      find.byKey(const ValueKey('matrix-scrollbar-unclassified')),
      findsOneWidget,
    );

    await _dispose(tester, db);
  });

  testWidgets('empty tray is compact', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpMatrix(tester, db);
    final trayHeight = tester
        .getSize(find.byKey(const ValueKey('matrix-unclassified')))
        .height;
    expect(trayHeight, lessThan(80));

    await _dispose(tester, db);
  });

  testWidgets('tall viewport gives taller quadrants', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    final now = DateTime.now();
    await repo.createTask(
      title: 'Do first task',
      priority: 3,
      dueDate: _date(now.add(const Duration(days: 1))),
    );

    await _pumpMatrix(tester, db);
    final fieldHeight = tester
        .getSize(find.byKey(const ValueKey('matrix-field-doFirst')))
        .height;
    expect(fieldHeight, greaterThan(300));

    await _dispose(tester, db);
  });

  testWidgets('2.5x and 3x large text scaling does not overflow', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final textScale in const [2.5, 3.0]) {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = TaskRepository(db);
      for (var i = 0; i < 6; i++) {
        await repo.createTask(title: 'Task number $i', priority: i % 4);
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: const MatrixScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('matrix-unclassified')), findsOneWidget);

      await _dispose(tester, db);
    }
  });

  testWidgets('next row is partially visible at scroll offset zero', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    final now = DateTime.now();
    final ids = <String>[];
    for (var i = 0; i < 12; i++) {
      ids.add(
        await repo.createTask(
          title: 'Do first $i',
          priority: 3,
          dueDate: _date(now.add(const Duration(days: 1))),
        ),
      );
    }

    await _pumpMatrix(tester, db);
    final listRect = tester.getRect(
      find.byKey(const ValueKey('matrix-list-doFirst')),
    );
    final partiallyVisible = ids.where((id) {
      final finder = find.byKey(ValueKey('matrix-task-$id'));
      if (finder.evaluate().isEmpty) return false;
      final rect = tester.getRect(finder);
      return rect.top >= listRect.top &&
          rect.top < listRect.bottom &&
          rect.bottom > listRect.bottom;
    });
    expect(partiallyVisible, isNotEmpty);

    await _dispose(tester, db);
  });

  testWidgets('max scroll shows the last task and checkbox fully', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    final now = DateTime.now();
    final ids = <String>[];
    for (var i = 0; i < 12; i++) {
      ids.add(
        await repo.createTask(
          title: 'Do first $i',
          priority: 3,
          dueDate: _date(now.add(const Duration(days: 1))),
        ),
      );
    }

    await _pumpMatrix(tester, db);
    await tester.drag(
      find.byKey(const ValueKey('matrix-list-doFirst')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();

    final lastId = ids.last;
    final cardRect = tester.getRect(
      find.byKey(const ValueKey('matrix-field-doFirst')),
    );
    final checkboxRect = tester.getRect(
      find.byKey(ValueKey('matrix-complete-$lastId')),
    );
    final textRect = tester.getRect(
      find.descendant(
        of: find.byKey(ValueKey('matrix-task-$lastId')),
        matching: find.text('Do first 11'),
      ),
    );
    expect(find.text('Do first 11'), findsOneWidget);
    expect(checkboxRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    expect(textRect.bottom, lessThanOrEqualTo(cardRect.bottom));

    await _dispose(tester, db);
  });

  testWidgets('switching auto and priority recreates field controllers', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    final now = DateTime.now();
    for (var i = 0; i < 12; i++) {
      await repo.createTask(
        title: 'Do first $i',
        priority: 3,
        dueDate: _date(now.add(const Duration(days: 1))),
      );
    }

    await _pumpMatrix(tester, db);
    await tester.drag(
      find.byKey(const ValueKey('matrix-list-doFirst')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Priority'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Auto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('matrix-field-doFirst')), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('matrix-list-doFirst')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, 0);

    await _dispose(tester, db);
  });

  testWidgets('drag after scrolling still moves a task between fields', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    final ids = <String>[];
    for (var i = 0; i < 12; i++) {
      ids.add(await repo.createTask(title: 'P1 task $i', priority: 4));
    }

    await _pumpMatrix(tester, db);
    await tester.tap(find.text('Priority'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.drag(
      find.byKey(const ValueKey('matrix-list-p1')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(ValueKey('matrix-task-${ids.last}'));
    final target = find.byKey(const ValueKey('matrix-field-p2'));
    final gesture = await tester.startGesture(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('matrix-field-p2')),
        matching: find.text('P1 task 11'),
      ),
      findsOneWidget,
    );

    await _dispose(tester, db);
  });

  testWidgets('empty tray adapts to 2.5x and 3x text without overflow', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in const [Size(320, 480), Size(800, 1200)]) {
      for (final textScale in const [2.5, 3.0]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final db = AppDatabase.forTesting(NativeDatabase.memory());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: const MatrixScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('matrix-unclassified')),
          findsOneWidget,
        );

        await _dispose(tester, db);
      }
    }
  });

  testWidgets('populated tray stays capped and scrollable at 3x text', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    for (var i = 0; i < 20; i++) {
      await repo.createTask(title: 'Unclassified $i');
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
            child: const MatrixScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    final trayHeight = tester
        .getSize(find.byKey(const ValueKey('matrix-unclassified')))
        .height;
    expect(trayHeight, lessThanOrEqualTo(280));
    expect(
      find.byKey(const ValueKey('matrix-scrollbar-unclassified')),
      findsOneWidget,
    );

    await _dispose(tester, db);
  });
}

Future<void> _pumpMatrix(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: MatrixScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
  await tester.pump();
}

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
