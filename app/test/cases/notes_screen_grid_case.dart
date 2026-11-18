import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/notes/presentation/notes_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> seed(AppDatabase db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'older',
            title: const Value('older'),
            body: const Value('body'),
            createdAt: now - 1000,
            updatedAt: now - 1000,
          ),
        );
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'newer',
            title: const Value('newer'),
            body: const Value('body2'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  testWidgets('default renders grid with newest first', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seed(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byKey(const Key('notes-grid')), findsOneWidget);
    final titles = tester.widgetList<Text>(find.byType(Text)).toList();
    final newerIndex = titles.indexWhere((t) => t.data == 'newer');
    final olderIndex = titles.indexWhere((t) => t.data == 'older');
    expect(newerIndex, greaterThanOrEqualTo(0));
    expect(olderIndex, greaterThanOrEqualTo(0));
    expect(newerIndex, lessThan(olderIndex));

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('prefs initialized to list renders list on first build', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'notes.viewMode': 'list'});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seed(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byKey(const Key('notes-list')), findsOneWidget);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('toggle persists and survives new instance', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seed(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byKey(const Key('notes-grid')), findsOneWidget);
    await tester.tap(find.byTooltip('List view'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.byKey(const Key('notes-list')), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('notes.viewMode'), 'list');

    // Fresh instance reads persisted choice.
    await tester.pumpWidget(Container());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.byKey(const Key('notes-list')), findsOneWidget);

    await db.close();
    await tester.pumpWidget(Container());
    await tester.pump();
  });

  testWidgets('folder tap opens it and breadcrumb returns to all notes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.folders)
        .insert(
          FoldersCompanion.insert(
            id: 'folder',
            name: 'Work',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    await tester.tap(find.text('Work').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('No notes here'), findsOneWidget);
    expect(find.text('Work'), findsWidgets);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('notes.selectedFolder'), 'folder');

    await tester.tap(find.text('All notes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('All notes'), findsOneWidget);

    // Dispose the tree first so Drift streams cancel before the database closes.
    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('renders grid and list at 320dp with 200% text', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await seed(db);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: const NotesScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byKey(const Key('notes-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('List view'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byKey(const Key('notes-list')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
    await db.close();
  });
}
