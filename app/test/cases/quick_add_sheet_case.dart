import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/design/theme.dart';
import 'package:ephemeron/core/time/picker_memory.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/domain/habits/date_key.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart';
import 'package:ephemeron/features/tasks/presentation/quick_add_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('quick add opens as a centered dialog on desktop widths', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpHost(tester, db);
    await _open(tester);

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Quick add'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('task chips set date, list and priority', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    await repo.createList('Home');
    await repo.createList('Inbox');
    await _pumpHost(tester, db);
    await _open(tester);

    final home = (await db.select(db.taskLists).get()).firstWhere(
      (l) => l.name == 'Home',
    );
    await tester.enterText(find.byType(TextField), 'Buy milk #work 9h');
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(ValueKey('quick-add-list-${home.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('quick-add-list-${home.id}')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('quick-add-priority-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-add-priority-1')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('quick-add-date-today')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-add-date-today')));
    await tester.pump();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('#work'), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^P[1-4]$').hasMatch(w.data ?? ''),
      ),
      findsNothing,
    );

    final addTaskButton = find.widgetWithText(FilledButton, 'Add task');
    await tester.dragUntilVisible(
      addTaskButton,
      find.byType(SingleChildScrollView).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(addTaskButton);
    await tester.pumpAndSettle();

    final rows = await db.select(db.tasks).get();
    expect(rows, hasLength(1));
    final list = (await db.select(db.taskLists).get()).firstWhere(
      (l) => l.name == 'Home',
    );
    final today = formatYmd(DateTime.now());
    expect(rows.single.title, 'Buy milk');
    expect(rows.single.listId, list.id);
    expect(rows.single.priority, 4);
    expect(rows.single.dueDate, today);
    expect(rows.single.dueTime, 9 * 60);
    expect(await db.select(db.taskTags).get(), hasLength(1));

    await _dispose(tester, db);
  });

  testWidgets('parsed list name creates or reuses the list', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    final inbox = await repo.createList('Inbox');
    await _pumpHost(tester, db);
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'Buy milk ~Inbox');
    await tester.pump();
    final addTaskButton = find.widgetWithText(FilledButton, 'Add task');
    await tester.dragUntilVisible(
      addTaskButton,
      find.byType(SingleChildScrollView).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(addTaskButton);
    await tester.pumpAndSettle();

    final task = (await db.select(db.tasks).get()).single;
    expect(task.listId, inbox);

    await _dispose(tester, db);
  });

  testWidgets('event chip creates a one-hour event in the default calendar', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = EventRepository(db, OccurrenceRepository(db));
    final calendarId = await repo.createCalendar('Calendar');
    await _pumpHost(tester, db);
    await _open(tester);

    final container = _container(tester);
    container.read(occurrenceDirtyProvider.notifier).clear();

    await tester.ensureVisible(
      find.byKey(const ValueKey('quick-add-kind-event')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-add-kind-event')));
    await tester.enterText(find.byType(TextField), 'Standup tomorrow 9h');
    await tester.pump();
    final addEventBtn = find.widgetWithText(FilledButton, 'Add event');
    await tester.ensureVisible(addEventBtn);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(addEventBtn);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Could not add. Try again.'), findsNothing);
    final event = (await db.select(db.events).get()).single;
    expect(event.title, 'Standup');
    expect(event.calendarId, calendarId);
    expect(event.startUtc, isNotNull);
    expect(
      event.endUtc! - event.startUtc!,
      const Duration(hours: 1).inMilliseconds,
    );
    expect(container.read(occurrenceDirtyProvider), isTrue);

    await _dispose(tester, db);
  });

  testWidgets('habit chip creates a daily habit starting today', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpHost(tester, db);
    await _open(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('quick-add-kind-habit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-add-kind-habit')));
    await tester.pump();
    expect(find.byKey(const ValueKey('quick-add-date-today')), findsNothing);

    await tester.enterText(find.byType(TextField), 'Meditate');
    await tester.pump();
    final addHabitButton = find.widgetWithText(FilledButton, 'Add habit');
    await tester.dragUntilVisible(
      addHabitButton,
      find.byType(SingleChildScrollView).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(addHabitButton);
    await tester.pumpAndSettle();

    final habit = (await db.select(db.habits).get()).single;
    expect(habit.name, 'Meditate');
    expect(habit.frequency, 'daily');
    expect(habit.startDate, habitDateKey(DateTime.now()));

    await _dispose(tester, db);
  });

  testWidgets('countdown chip defaults to thirty days out', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpHost(tester, db);
    await _open(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('quick-add-kind-countdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-add-kind-countdown')));
    await tester.enterText(find.byType(TextField), 'Trip');
    await tester.pump();
    final addCountdownBtn = find.widgetWithText(FilledButton, 'Add countdown');
    await tester.ensureVisible(addCountdownBtn);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(addCountdownBtn);
    await tester.pumpAndSettle();

    final countdown = (await db.select(db.countdowns).get()).single;
    expect(countdown.title, 'Trip');
    final target = DateTime.parse(countdown.targetDate!);
    final days = target
        .difference(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        )
        .inDays;
    expect(days, inInclusiveRange(29, 31));

    await _dispose(tester, db);
  });

  testWidgets('add another keeps the sheet open and clears the field', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpHost(tester, db);
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'First');
    await tester.pump();
    final addAnotherBtn = find.widgetWithText(OutlinedButton, 'Add another');
    await tester.ensureVisible(addAnotherBtn);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(addAnotherBtn);
    await tester.pumpAndSettle();

    expect(find.text('Quick add'), findsOneWidget);
    expect(_field(tester).controller!.text, isEmpty);
    expect(await db.select(db.tasks).get(), hasLength(1));

    await tester.enterText(find.byType(TextField), 'Second');
    await tester.pump();
    final addTaskAfterAnotherBtn = find.widgetWithText(
      FilledButton,
      'Add task',
    );
    await tester.ensureVisible(addTaskAfterAnotherBtn);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(addTaskAfterAnotherBtn);
    await tester.pumpAndSettle();

    expect(find.text('Quick add'), findsNothing);
    expect(await db.select(db.tasks).get(), hasLength(2));

    await _dispose(tester, db);
  });

  testWidgets('Enter submits the task and closes', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpHost(tester, db);
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'Enter task');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Quick add'), findsNothing);
    expect((await db.select(db.tasks).get()).single.title, 'Enter task');

    await _dispose(tester, db);
  });

  testWidgets('restored draft prefills text and kind', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpHost(
      tester,
      db,
      restoredDraft: const <String, dynamic>{
        'text': 'Meditate every day',
        'kind': 'habit',
      },
    );
    await tester.tap(find.text('restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_field(tester).controller!.text, 'Meditate every day');
    expect(find.widgetWithText(FilledButton, 'Add habit'), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('draft autosaves on close and restores on reopen', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpHost(tester, db);
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'Draft me');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await _open(tester);
    expect(_field(tester).controller!.text, 'Draft me');

    await _dispose(tester, db);
  });

  testWidgets('preview keeps its size and actions do not move while typing', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpHost(tester, db);
    await _open(tester);

    final preview = find.byKey(const ValueKey<String>('quick_add_preview'));
    final button = find.widgetWithText(FilledButton, 'Add task');
    final before = tester.getSize(preview);
    final buttonBefore = tester.getTopLeft(button);

    await tester.enterText(
      find.byType(TextField),
      'Buy milk #work ~home -p1 tomorrow 9h every day',
    );
    await tester.pump();

    expect(tester.getSize(preview), before);
    expect(tester.getTopLeft(button), buttonBefore);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('quick add fits 320dp at 200% text scale', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskRepository(db);
    await repo.createList('List 0');
    await _pumpHost(tester, db, width: 320, height: 640, textScale: 2);
    await _open(tester);

    expect(find.byType(Dialog), findsNothing);
    final preview = find.byKey(const ValueKey<String>('quick_add_preview'));
    final before = tester.getSize(preview);

    await tester.enterText(
      find.byType(TextField),
      'Buy milk #tag0 ~"List 0" -p1 tomorrow 9h every day',
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(preview), before);
    expect(find.text('Quick add'), findsOneWidget);
    expect(find.text('Daily'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Add task'), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('failed creates keep the sheet open with an error', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpHost(tester, db);
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'Will fail');
    await tester.pump();
    await db.close();

    final addTaskButton = find.widgetWithText(FilledButton, 'Add task');
    await tester.dragUntilVisible(
      addTaskButton,
      find.byType(SingleChildScrollView).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(addTaskButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Could not add. Try again.'), findsOneWidget);
    expect(find.text('Quick add'), findsOneWidget);

    await _dispose(tester, db, closeDatabase: false);
  });

  testWidgets('missing writable calendar falls back to the event editor', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpHost(tester, db);
    await _open(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('quick-add-kind-event')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-add-kind-event')));
    await tester.enterText(find.byType(TextField), 'No calendar event');
    await tester.pump();
    final addEventFallbackBtn = find.widgetWithText(FilledButton, 'Add event');
    await tester.ensureVisible(addEventFallbackBtn);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(addEventFallbackBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Quick add'), findsNothing);
    expect(find.text('No calendar event'), findsOneWidget);
    expect(await db.select(db.events).get(), isEmpty);

    await _dispose(tester, db);
  });
}

Future<void> _pumpHost(
  WidgetTester tester,
  AppDatabase db, {
  double width = 800,
  double height = 600,
  double textScale = 1,
  Map<String, dynamic>? restoredDraft,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
        theme: EphemeronTheme.build(
          mode: 'light',
          platformBrightness: Brightness.light,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, child) {
              // Mirrors the shell/calendar keeping the calendar list warm.
              ref.watch(calendarsProvider);
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => showQuickAdd(context),
                      child: const Text('open'),
                    ),
                    TextButton(
                      onPressed: () =>
                          showQuickAdd(context, restoredDraft: restoredDraft),
                      child: const Text('restore'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

Future<void> _dispose(
  WidgetTester tester,
  AppDatabase db, {
  bool closeDatabase = true,
}) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  if (closeDatabase) await db.close();
  await tester.pump();
}
