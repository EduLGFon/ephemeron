// Large accessibility text scaling for the matrix board and task editor.
// Both layouts are otherwise covered only at the default text scale.
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/tasks/presentation/matrix_screen.dart';
import 'package:ephemeron/features/tasks/presentation/task_editor_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';


AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('matrix renders at 2.5x and 3x text without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final textScale in const [2.5, 3.0]) {
      final db = _db();
      try {
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
        expect(
          find.byKey(const ValueKey('matrix-unclassified')),
          findsOneWidget,
        );
      } finally {
        await _dispose(tester, db);
      }
    }
  });

  testWidgets('task editor renders at 2.5x and 3x text without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final textScale in const [2.5, 3.0]) {
      final db = _db();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: TextButton(
                        onPressed: () => showTaskEditor(context),
                        child: const Text('Open editor'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
        for (var value = 0; value <= 4; value++) {
          expect(
            find.byKey(ValueKey('task-editor-priority-$value')),
            findsOneWidget,
          );
        }
        expect(find.byIcon(Icons.flag), findsWidgets);
        expect(find.byIcon(Icons.flag_outlined), findsWidgets);
        expect(
          find.byWidgetPredicate(
            (w) => w is Text && RegExp(r'^P[1-4]$').hasMatch(w.data ?? ''),
          ),
          findsNothing,
        );
      } finally {
        await _dispose(tester, db);
      }
    }
  });
}
