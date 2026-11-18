// UX search suite: snippet highlighting, tag task lookup, and the empty,
// loading and no-results states with provider overrides.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/design/components/app_chips.dart';
import 'package:ephemeron/core/design/components/app_states.dart';
import 'package:ephemeron/core/search/limits.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/note_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/search/application/search_providers.dart';
import 'package:ephemeron/features/search/presentation/search_screen.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/features/sync/application/pending_operations.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SearchScreen(),
    ),
  );
}

Future<SettingsRepository> _settings() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SettingsRepository(await SharedPreferences.getInstance());
}

void main() {
  test('highlightSnippet bolds every case-insensitive query match', () {
    final spans = highlightSnippet('milk and MILK and Milk', 'mIlK');
    expect(spans.map((s) => s.text).join(), 'milk and MILK and Milk');
    expect(spans.where((s) => s.bold).map((s) => s.text), [
      'milk',
      'MILK',
      'Milk',
    ]);
  });

  test('highlightSnippet preserves literal b markers', () {
    final spans = highlightSnippet('<b> match </b>', 'match');
    expect(spans.map((s) => s.text).join(), '<b> match </b>');
    expect(spans.firstWhere((s) => s.text == '<b> ').bold, isFalse);
    expect(spans.firstWhere((s) => s.text == 'match').bold, isTrue);
    expect(spans.firstWhere((s) => s.text == ' </b>').bold, isFalse);
  });

  test('highlightSnippet returns one span for an empty query', () {
    final spans = highlightSnippet('literal <b>text</b>', '');
    expect(spans, hasLength(1));
    expect(spans.single.text, 'literal <b>text</b>');
    expect(spans.single.bold, isFalse);
  });

  test('searchTasksForTag returns only tagged open tasks', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final listId = await repo.createList('Inbox');
    await repo.createTask(title: 'Other', listId: listId);
    final tagged = await repo.createTask(
      title: 'Buy milk',
      listId: listId,
      tags: ['groceries'],
    );
    final tag = (await repo.searchTags('groc')).single;

    final results = await repo.searchTasksForTag(tag.id);
    expect(results.map((t) => t.title), ['Buy milk']);

    await repo.completeTask(tagged);
    expect(await repo.searchTasksForTag(tag.id), isEmpty);
  });

  test('searchTasksForTag excludes soft and pending deletes', () async {
    final db = _db();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final repo = TaskRepository(db);
    final listId = await repo.createList('Inbox');
    await repo.createTask(title: 'Keep', listId: listId, tags: ['groceries']);
    final softDeleted = await repo.createTask(
      title: 'Soft deleted',
      listId: listId,
      tags: ['groceries'],
    );
    final pendingDeleted = await repo.createTask(
      title: 'Pending delete',
      listId: listId,
      tags: ['groceries'],
    );
    final tag = (await repo.searchTags('groc')).single;

    await repo.softDeleteTasks([softDeleted]);
    final pendingOps = container.read(pendingOperationsProvider);
    final pendingOpId = await pendingOps.scheduleTaskDelete(pendingDeleted);

    final results = await repo.searchTasksForTag(tag.id);
    expect(results.map((t) => t.title), ['Keep']);

    // Cancel the undo timer before this test's database closes; otherwise it
    // can fire during a later test and query the closed database.
    await pendingOps.cancel(pendingOpId);
    pendingOps.dispose();
  });

  test('searchTasksForTag defaults to the shared tag task limit', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final listId = await repo.createList('Inbox');
    for (var i = 0; i < tagTaskLimit + 1; i++) {
      await repo.createTask(
        title: 'Tagged $i',
        listId: listId,
        tags: ['groceries'],
      );
    }
    final tag = (await repo.searchTags('groc')).single;

    final results = await repo.searchTasksForTag(tag.id);
    expect(results, hasLength(tagTaskLimit));
  });

  testWidgets('empty query shows actionable example searches', (tester) async {
    final db = _db();
    addTearDown(db.close);
    final settings = await _settings();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith((ref) async => settings),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('Type to search.'), findsOneWidget);
    expect(find.widgetWithText(AppChip, 'milk'), findsOneWidget);
    expect(find.widgetWithText(AppChip, 'meeting'), findsOneWidget);
    expect(find.widgetWithText(AppChip, 'gym'), findsOneWidget);
  });

  testWidgets('escape clears a non-empty query', (tester) async {
    final db = _db();
    addTearDown(db.close);
    final settings = await _settings();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith((ref) async => settings),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'milk');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Clear search'), findsNothing);
    expect(find.text('Type to search.'), findsOneWidget);
  });

  testWidgets('all-empty results show no results with a clear action', (
    tester,
  ) async {
    final db = _db();
    addTearDown(db.close);
    final settings = await _settings();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith((ref) async => settings),
        searchTasksProvider.overrideWith((ref) async => <Task>[]),
        searchEventsProvider.overrideWith((ref) async => <Event>[]),
        searchNotesProvider.overrideWith((ref) async => <NoteSearchHit>[]),
        searchHabitsProvider.overrideWith((ref) async => <Habit>[]),
        searchCountdownsProvider.overrideWith((ref) async => <Countdown>[]),
        searchTagsProvider.overrideWith((ref) async => <Tag>[]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.byTooltip('Clear search'), findsOneWidget);
    expect(find.text('No results'), findsOneWidget);
    expect(find.text('Nothing matched "zzzz".'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('No results'), findsNothing);
    expect(find.text('Type to search.'), findsOneWidget);
  });

  testWidgets('group errors show search failed with retry', (tester) async {
    final db = _db();
    addTearDown(db.close);
    var attempts = 0;
    final settings = await _settings();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith((ref) async => settings),
        searchTasksProvider.overrideWith((ref) async {
          attempts++;
          throw StateError('boom');
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('Search failed'), findsOneWidget);
    expect(find.text('No results'), findsNothing);
    expect(attempts, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, greaterThan(1));
  });

  testWidgets(
    'a failed group surfaces retry even when other groups have rows',
    (tester) async {
      final db = _db();
      addTearDown(db.close);
      final repo = TaskRepository(db);
      final listId = await repo.createList('Inbox');
      await repo.createTask(title: 'Milk run', listId: listId);
      var attempts = 0;
      final settings = await _settings();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWith((ref) async => settings),
          searchEventsProvider.overrideWith((ref) async {
            attempts++;
            throw StateError('boom');
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search-field')), 'milk');
      await tester.pumpAndSettle();

      expect(find.text('Milk run'), findsOneWidget);
      expect(find.text('Events failed to load'), findsOneWidget);
      expect(find.text('Search failed'), findsNothing);
      expect(attempts, 1);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(attempts, greaterThan(1));
    },
  );

  testWidgets('unresolved groups show the list skeleton, then no results', (
    tester,
  ) async {
    final db = _db();
    addTearDown(db.close);
    final tasks = Completer<List<Task>>();
    final events = Completer<List<Event>>();
    final notes = Completer<List<NoteSearchHit>>();
    final habits = Completer<List<Habit>>();
    final countdowns = Completer<List<Countdown>>();
    final tags = Completer<List<Tag>>();
    final settings = await _settings();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith((ref) async => settings),
        searchTasksProvider.overrideWith((ref) => tasks.future),
        searchEventsProvider.overrideWith((ref) => events.future),
        searchNotesProvider.overrideWith((ref) => notes.future),
        searchHabitsProvider.overrideWith((ref) => habits.future),
        searchCountdownsProvider.overrideWith((ref) => countdowns.future),
        searchTagsProvider.overrideWith((ref) => tags.future),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'zzzz');
    await tester.pump();

    expect(find.byType(AppSkeletonList), findsOneWidget);

    tasks.complete(<Task>[]);
    events.complete(<Event>[]);
    notes.complete(<NoteSearchHit>[]);
    habits.complete(<Habit>[]);
    countdowns.complete(<Countdown>[]);
    tags.complete(<Tag>[]);
    await tester.pumpAndSettle();

    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('search renders at 320dp with 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = _db();
    addTearDown(db.close);
    final settings = await _settings();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith((ref) async => settings),
        searchTasksProvider.overrideWith((ref) async => <Task>[]),
        searchEventsProvider.overrideWith((ref) async => <Event>[]),
        searchNotesProvider.overrideWith((ref) async => <NoteSearchHit>[]),
        searchHabitsProvider.overrideWith((ref) async => <Habit>[]),
        searchCountdownsProvider.overrideWith((ref) async => <Countdown>[]),
        searchTagsProvider.overrideWith((ref) async => <Tag>[]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: const SearchScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Search'), findsOneWidget);
    expect(find.byKey(const Key('search-field')), findsOneWidget);
    expect(find.text('Type to search.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-field')), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('No results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
