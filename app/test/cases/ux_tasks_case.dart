import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/domain/parsing/quick_add_parser.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/features/tasks/presentation/quick_add_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('quick add shorthands', () {
    test('append and toggle never duplicate a token', () {
      expect(appendQuickAddShorthand('Buy milk', '~home'), 'Buy milk ~home');
      expect(
        appendQuickAddShorthand('Buy milk ~home', '~home'),
        'Buy milk ~home',
      );

      expect(toggleQuickAddShorthand('Buy milk', '#work'), 'Buy milk #work');
      expect(toggleQuickAddShorthand('Buy milk #work', '#work'), 'Buy milk');

      // A shorter token must not match a longer token with the same prefix.
      expect(
        appendQuickAddShorthand('Buy #workout', '#work'),
        'Buy #workout #work',
      );
      expect(toggleQuickAddShorthand('Buy  #work  milk', '#work'), 'Buy milk');
    });

    test('tokens glued to punctuation are detected', () {
      expect(appendQuickAddShorthand('Buy ~home!', '~home'), 'Buy ~home!');
      expect(toggleQuickAddShorthand('Buy ~home!', '~home'), 'Buy !');

      expect(appendQuickAddShorthand('Buy #work.', '#work'), 'Buy #work.');
      expect(toggleQuickAddShorthand('Buy #work.', '#work'), 'Buy .');
    });

    test('names with spaces use quoted shorthand tokens', () {
      expect(quickAddListToken('My List'), '~"My List"');
      expect(quickAddTagToken('my tag'), '#"my tag"');
      expect(quickAddListToken('home'), '~home');
      expect(quickAddTagToken('work'), '#work');

      final parsed = parseQuickAdd('Buy milk ~"My List" #"my tag"');
      expect(parsed.title, 'Buy milk');
      expect(parsed.list, 'My List');
      expect(parsed.tags, ['my tag']);

      final plain = parseQuickAdd('Buy milk ~home #work');
      expect(plain.title, 'Buy milk');
      expect(plain.list, 'home');
      expect(plain.tags, ['work']);

      final token = quickAddListToken('My List');
      final appended = appendQuickAddShorthand('Buy milk', token);
      expect(appended, 'Buy milk ~"My List"');
      expect(appendQuickAddShorthand(appended, token), appended);
      expect(toggleQuickAddShorthand(appended, token), 'Buy milk');
    });

    test('date chips append parser tokens once', () {
      final today = quickAddDateChoices.firstWhere((c) => c.label == 'Today');
      final nextWeek = quickAddDateChoices.firstWhere(
        (c) => c.label == 'Next week',
      );
      final now = DateTime(2026, 3, 2, 8);

      final todayText = appendQuickAddShorthand('Buy milk', today.token);
      expect(todayText, 'Buy milk today');
      expect(appendQuickAddShorthand(todayText, today.token), todayText);
      expect(parseQuickAdd(todayText, now: now).due, DateTime(2026, 3, 2));

      final nextWeekText = appendQuickAddShorthand('Buy milk', nextWeek.token);
      expect(nextWeekText, 'Buy milk in 7 days');
      expect(
        appendQuickAddShorthand(nextWeekText, nextWeek.token),
        nextWeekText,
      );
      expect(parseQuickAdd(nextWeekText, now: now).due, DateTime(2026, 3, 9));
    });

    test('repeat preview is friendly instead of a raw rrule', () {
      expect(quickAddRepeatLabel('FREQ=DAILY'), 'Daily');
      expect(quickAddRepeatLabel('FREQ=WEEKLY;BYDAY=MO'), 'Weekly on Mon');
      expect(quickAddRepeatLabel('FREQ=MONTHLY'), 'Monthly');
      expect(quickAddRepeatLabel('FREQ=HOURLY'), 'Custom repeat');
    });
  });

  testWidgets('quick add previews parsed details and saves a lasting task', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpQuickAddHost(tester, db);

    await _openQuickAdd(tester);
    expect(find.text('Quick add'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Buy milk #work ~home -p1 tomorrow 9h',
    );
    await tester.pump();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('#work'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Task added'), findsOneWidget);
    final rows = await db.select(db.tasks).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Buy milk');
    expect(rows.single.deletedAt, isNull);

    // No eager delete: the task stays after the undo window elapses.
    await tester.pump(const Duration(seconds: 7));
    final afterWindow = await db.select(db.tasks).get();
    expect(afterWindow, hasLength(1));
    expect(afterWindow.single.deletedAt, isNull);

    await _dispose(tester, db);
  });

  testWidgets('undo on task added soft-deletes the task', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpQuickAddHost(tester, db);

    await _openQuickAdd(tester);
    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Task added'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.tasks).get();
    expect(rows, hasLength(1));
    expect(rows.single.deletedAt, isNotNull);

    await _dispose(tester, db);
  });

  testWidgets('quick add fits a 320dp screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    for (var i = 0; i < 5; i++) {
      await repo.createList('List $i');
      await repo.createTask(title: 'Seed $i', tags: ['tag$i']);
    }

    await _pumpQuickAddHost(tester, db);
    await _openQuickAdd(tester);
    await tester.enterText(
      find.byType(TextField),
      'Buy milk #tag0 ~"List 0" -p1 tomorrow 9h every day',
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Quick add'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('List 0'), findsOneWidget);

    await _dispose(tester, db);
  });
}

Future<void> _pumpQuickAddHost(WidgetTester tester, AppDatabase db) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith(
          (ref) async => SettingsRepository(prefs),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showQuickAdd(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openQuickAdd(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await db.close();
  await tester.pump();
}
