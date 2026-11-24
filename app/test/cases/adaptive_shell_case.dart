import 'package:ephemeron/app/shell/adaptive_shell.dart';
import 'package:ephemeron/app/shell/quick_create_pill.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/core/design/components/app_wheel.dart';
import 'package:ephemeron/core/ui/app_sheet.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_fixtures.dart';

Widget _harness({
  required List<int> primary,
  List<int> secondary = const <int>[5, 6, 7],
  int currentIndex = 0,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  ValueChanged<int>? onSelected,
  VoidCallback? onMore,
  VoidCallback? onSettings,
  Widget? content,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          padding: padding,
          viewInsets: viewInsets,
        ),
        child: AdaptiveShell(
          currentIndex: currentIndex,
          content: content ?? const Center(child: Text('Body')),
          primary: primary,
          secondary: secondary,
          onDestinationSelected: onSelected ?? (_) {},
          onMore: onMore ?? () {},
          onSettings: onSettings ?? () {},
        ),
      ),
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps the quick-create pill in an isolated scope. [extra] is stacked above
/// the pill and is used by the z-order test to host a modal entity sheet.
Future<ProviderContainer> _pumpPill(
  WidgetTester tester, {
  Size size = const Size(500, 900),
  Widget? extra,
}) async {
  _setSize(tester, size);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      taskListsProvider.overrideWith((ref) => Stream.value(const <TaskList>[])),
      settingsRepositoryProvider.overrideWith(
        (ref) async => SettingsRepository(prefs),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              const Center(child: QuickCreatePill()),
              ?extra,
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

const Key pillKey = ValueKey<String>('quick-create-pill');
const Key pillInputKey = ValueKey<String>('quick-create-input');
const Key pillCardKey = ValueKey<String>('quick-create-card');
const Key pillHandleKey = ValueKey<String>('quick-create-drag-handle');
const Key pillLayerKey = ValueKey<String>('quick-create-layer');
const Key pillBarrierKey = ValueKey<String>('quick-create-barrier');

/// Whether the wheel row carrying [key] exposes selected semantics. Used to
/// assert which value a wheel actually shows, not just which rows exist.
bool _wheelRowSelected(WidgetTester tester, String key) {
  final semantics = tester.widget<Semantics>(
    find
        .ancestor(
          of: find.byKey(ValueKey<String>(key)),
          matching: find.byType(Semantics),
        )
        .first,
  );
  return semantics.properties.selected ?? false;
}

NavigationBar _bar(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

/// Opacity of the label fade inside the destination that shows [label].
double _labelOpacity(WidgetTester tester, String label) =>
    _labelFade(tester, label).opacity.value;

FadeTransition _labelFade(WidgetTester tester, String label) {
  return tester.widget<FadeTransition>(
    find
        .ancestor(of: find.text(label), matching: find.byType(FadeTransition))
        .first,
  );
}

late AppDatabase db;

void main() {
  setUpAll(() async {
    db = newTestDb();
  });
  tearDownAll(() async {});
  setUp(() async {
    await resetTestDb(db);
  });
  testWidgets('compact width uses bottom navigation and a quick-create pill', (
    tester,
  ) async {
    _setSize(tester, const Size(400, 800));
    await tester.pumpWidget(_harness(primary: const <int>[0, 1, 2, 3, 4]));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('quick-create-pill')),
      findsOneWidget,
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('medium width uses a navigation rail', (tester) async {
    _setSize(tester, const Size(700, 900));
    await tester.pumpWidget(_harness(primary: const <int>[0, 1, 2, 3, 4]));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('expanded width uses a labelled sidebar', (tester) async {
    _setSize(tester, const Size(1000, 900));
    await tester.pumpWidget(_harness(primary: const <int>[0, 1, 2, 3, 4]));

    expect(find.byKey(const ValueKey<String>('shell-sidebar')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Ephemeron'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('primary destinations follow the persisted order', (
    tester,
  ) async {
    _setSize(tester, const Size(400, 800));
    await tester.pumpWidget(_harness(primary: const <int>[4, 0, 1, 2, 3]));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(
      bar.destinations.map((d) => (d as NavigationDestination).label).toList(),
      <String>['Focus', 'Today', 'Tasks', 'Calendar', 'Habits', 'More'],
    );

    int? selected;
    await tester.pumpWidget(
      _harness(
        primary: const <int>[4, 0, 1, 2, 3],
        onSelected: (value) => selected = value,
      ),
    );
    await tester.tap(find.text('Tasks'));
    await tester.pump();
    expect(selected, 1);
  });

  testWidgets('Stream appears only when enabled in the secondary list', (
    tester,
  ) async {
    _setSize(tester, const Size(1000, 900));
    await tester.pumpWidget(_harness(primary: const <int>[0, 1, 2, 3, 4]));
    expect(find.text('Stream'), findsNothing);

    await tester.pumpWidget(
      _harness(
        primary: const <int>[0, 1, 2, 3, 4],
        secondary: const <int>[5, 6, 7, 8],
      ),
    );
    expect(find.text('Stream'), findsOneWidget);
    expect(find.text('Countdowns'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Matrix'), findsOneWidget);
  });

  testWidgets('320dp at 200% text hides labels instead of clipping', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 640));
    await tester.pumpWidget(
      _harness(primary: const <int>[0, 1, 2, 3, 4], textScale: 2),
    );

    expect(tester.takeException(), isNull);
    final bar = _bar(tester);
    expect(bar.destinations, hasLength(6));
    expect(
      bar.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysHide,
      reason: 'narrow widths must not wrap six destination labels',
    );
    for (final label in <String>[
      'Today',
      'Tasks',
      'Calendar',
      'Habits',
      'Focus',
      'More',
    ]) {
      expect(find.text(label), findsOneWidget);
      expect(_labelOpacity(tester, label), 0, reason: '$label stays hidden');
    }
    // Hiding labels must not drop tooltips or semantics.
    final tooltips = tester
        .widgetList<Tooltip>(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byType(Tooltip),
          ),
        )
        .map((tooltip) => tooltip.message)
        .toList();
    expect(tooltips, hasLength(6));
    expect(tooltips, contains('Today (1)'));
    expect(tooltips, contains('More (C)'));
    // The faded label stays in the semantics tree for screen readers.
    expect(_labelFade(tester, 'Today').alwaysIncludeSemantics, isTrue);
  });

  testWidgets('411dp at normal text keeps compact labels visible', (
    tester,
  ) async {
    _setSize(tester, const Size(411, 891));
    await tester.pumpWidget(
      _harness(primary: const <int>[0, 1, 2, 3, 4], textScale: 1),
    );

    expect(tester.takeException(), isNull);
    final bar = _bar(tester);
    expect(bar.destinations, hasLength(6));
    expect(
      bar.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysShow,
      reason: 'labels must remain visible at normal phone widths',
    );
    for (final label in <String>['Today', 'Tasks', 'Calendar', 'More']) {
      expect(find.text(label), findsOneWidget);
      expect(_labelOpacity(tester, label), 1, reason: '$label stays visible');
    }
  });

  testWidgets('selected indicator stays inside the bar at 320dp/200%', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 640));
    for (final slot in <int>[0, 4]) {
      await tester.pumpWidget(
        _harness(
          primary: const <int>[0, 1, 2, 3, 4],
          currentIndex: slot,
          textScale: 2,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final bar = tester.getRect(find.byType(NavigationBar));
      final indicator = tester.getRect(
        find.byType(NavigationIndicator).at(slot),
      );
      // Six destinations leave a slot narrower than the 64dp Material default,
      // so the indicator is clamped to the slot and must stay on screen for
      // both the first and last destination.
      expect(indicator.left, greaterThanOrEqualTo(bar.left));
      expect(indicator.right, lessThanOrEqualTo(bar.right));
      expect(indicator.width, lessThanOrEqualTo(bar.width / 6 + 0.01));
      expect(indicator.width, greaterThan(0));
    }
  });

  testWidgets('compact bar keeps destinations above the bottom inset', (
    tester,
  ) async {
    _setSize(tester, const Size(411, 891));
    // Three-button Android navigation bars reserve about this much space.
    const gestureInset = 48.0;
    await tester.pumpWidget(
      _harness(
        primary: const <int>[0, 1, 2, 3, 4],
        padding: const EdgeInsets.only(bottom: gestureInset),
      ),
    );

    final bar = tester.getRect(find.byType(NavigationBar));
    final icon = tester.getRect(find.byIcon(Icons.today_outlined));
    // NavigationBar owns a bottom SafeArea; its content must stay clear of the
    // gesture area instead of painting under it.
    expect(icon.bottom, lessThanOrEqualTo(bar.bottom - gestureInset));
  });

  testWidgets('pushed pages keep a back affordance over the shell', (
    tester,
  ) async {
    _setSize(tester, const Size(400, 800));
    await tester.pumpWidget(
      _harness(
        primary: const <int>[0, 1, 2, 3, 4],
        content: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Pushed')),
                    body: const Text('Pushed body'),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pushed body'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Body'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'expanded quick-create pill does not overflow at small viewport with keyboard',
    (tester) async {
      _setSize(tester, const Size(360, 800));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListsProvider.overrideWith(
              (ref) => Stream.value(const <TaskList>[]),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                viewInsets: EdgeInsets.only(bottom: 320),
              ),
              child: AdaptiveShell(
                currentIndex: 0,
                content: const Center(child: Text('Body')),
                primary: const <int>[0, 1, 2, 3, 4],
                secondary: const <int>[5, 6, 7],
                onDestinationSelected: (_) {},
                onMore: () {},
                onSettings: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('quick-create-pill')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey<String>('quick-create-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('quick-create-kind-task')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('quick-create pill creates a habit', (tester) async {
    _setSize(tester, const Size(500, 800));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    addTearDown(() async => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          taskListsProvider.overrideWith(
            (ref) => Stream.value(const <TaskList>[]),
          ),
          settingsRepositoryProvider.overrideWith(
            (ref) async => SettingsRepository(prefs),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: QuickCreatePill())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey<String>('quick-create-pill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey<String>('quick-create-kind-habit')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey<String>('quick-create-input')),
      'Drink water',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('quick-create-submit')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final habits = await db.select(db.habits).get();
    expect(habits, hasLength(1));
    expect(habits.single.name, 'Drink water');
  });

  testWidgets('quick-create pill creates a countdown', (tester) async {
    _setSize(tester, const Size(500, 800));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    addTearDown(() async => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          taskListsProvider.overrideWith(
            (ref) => Stream.value(const <TaskList>[]),
          ),
          settingsRepositoryProvider.overrideWith(
            (ref) async => SettingsRepository(prefs),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: QuickCreatePill())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey<String>('quick-create-pill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey<String>('quick-create-kind-countdown')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey<String>('quick-create-input')),
      'Trip',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('quick-create-submit')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final countdowns = await db.select(db.countdowns).get();
    expect(countdowns, hasLength(1));
    expect(countdowns.single.title, 'Trip');
  });

  testWidgets(
    'quick-create pill falls back to event editor when no writable calendar exists',
    (tester) async {
      _setSize(tester, const Size(500, 800));
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      addTearDown(() async => db.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            taskListsProvider.overrideWith(
              (ref) => Stream.value(const <TaskList>[]),
            ),
            settingsRepositoryProvider.overrideWith(
              (ref) async => SettingsRepository(prefs),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: QuickCreatePill())),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey<String>('quick-create-pill')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.byKey(const ValueKey<String>('quick-create-kind-event')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byKey(const ValueKey<String>('quick-create-input')),
        'No calendar event',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('quick-create-submit')),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No calendar event'), findsWidgets);
      expect(await db.select(db.events).get(), isEmpty);

      await tester.pumpWidget(Container());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'expanded pill barrier fills the shell and the card stays on screen',
    (tester) async {
      _setSize(tester, const Size(400, 800));
      await tester.pumpWidget(_harness(primary: const <int>[0, 1, 2, 3, 4]));

      await tester.tap(find.byKey(pillKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final barrier = tester.getRect(find.byKey(pillBarrierKey));
      expect(barrier.width, greaterThan(300));
      expect(barrier.height, greaterThan(400));

      final card = tester.getRect(find.byKey(pillCardKey));
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.top, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(400));
      expect(card.bottom, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded pill lays out wheels around the input with icons above labels',
    (tester) async {
      await _pumpPill(tester);
      await tester.tap(find.byKey(pillKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // The default kind is shared across pill instances, so pin it to task.
      await tester.tap(
        find.byKey(const ValueKey<String>('quick-create-kind-task')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Type, Date and Priority become vertical wheels; no list exists yet.
      expect(
        find.byWidgetPredicate((widget) => widget is WheelSelector),
        findsNWidgets(3),
      );
      expect(
        find.byKey(const ValueKey<String>('quick-create-date-today')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('quick-create-prio-1')),
        findsOneWidget,
      );
      expect(find.byKey(pillInputKey), findsOneWidget);

      // Each selector shows its icon over its label (not inline in a chip).
      final iconRect = tester.getRect(
        find.byKey(const ValueKey<String>('quick-create-kind-icon')),
      );
      final labelRect = tester.getRect(find.text('Type'));
      expect(iconRect.bottom, lessThanOrEqualTo(labelRect.top));
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey<String>('quick-create-prio-icon')),
            )
            .bottom,
        lessThanOrEqualTo(tester.getRect(find.text('Priority')).top),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('priority wheel consumes the shared Eisenhower flag mapping', (
    tester,
  ) async {
    await _pumpPill(tester);
    await tester.tap(find.byKey(pillKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey<String>('quick-create-kind-task')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final pillElement = tester.element(find.byType(QuickCreatePill));
    final brightness = Theme.of(pillElement).brightness;
    final iconFinder = find.byKey(
      const ValueKey<String>('quick-create-prio-icon'),
    );
    final noneStyle = styleForVisualPriority(0);
    expect(
      tester.widget<Icon>(iconFinder).color,
      noneStyle.foreground(brightness),
    );

    await tester.tap(find.byKey(const ValueKey<String>('quick-create-prio-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final p1 = styleForVisualPriority(1);
    expect(tester.widget<Icon>(iconFinder).icon, p1.icon);
    expect(tester.widget<Icon>(iconFinder).color, p1.foreground(brightness));
  });

  testWidgets('tapping outside the expanded pill dismisses it', (tester) async {
    await _pumpPill(tester);
    await tester.tap(find.byKey(pillKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(pillInputKey), findsOneWidget);

    // Tap the top-left of the screen, well clear of the bottom-anchored card.
    await tester.tapAt(const Offset(20, 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(pillInputKey), findsNothing);
    expect(find.byKey(pillKey), findsOneWidget);
  });

  testWidgets(
    'drag up expands the pill to fullscreen and drag down restores it',
    (tester) async {
      await _pumpPill(tester);
      await tester.tap(find.byKey(pillKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final normal = tester.getRect(find.byKey(pillCardKey));

      await tester.drag(find.byKey(pillHandleKey), const Offset(0, -120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final fullscreen = tester.getRect(find.byKey(pillCardKey));
      expect(fullscreen.height, greaterThan(normal.height + 40));

      await tester.drag(find.byKey(pillHandleKey), const Offset(0, 120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final restored = tester.getRect(find.byKey(pillCardKey));
      expect(restored.height, lessThan(fullscreen.height - 40));
    },
  );

  testWidgets('switching the entity keeps the typed text', (tester) async {
    await _pumpPill(tester);
    await tester.tap(find.byKey(pillKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(pillInputKey), 'Buy milk');
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('quick-create-kind-event')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final field = tester.widget<TextField>(find.byKey(pillInputKey));
    expect(field.controller!.text, 'Buy milk');
    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets('the pill renders behind entity sheets', (tester) async {
    var sheetTaps = 0;
    final openSheet = Positioned(
      top: 16,
      left: 16,
      child: Builder(
        builder: (context) => TextButton(
          key: const ValueKey<String>('open-entity-sheet'),
          onPressed: () => showAppSheet<void>(
            context,
            builder: (_) => Center(
              key: const ValueKey<String>('entity-sheet'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Entity sheet'),
                  TextButton(
                    key: const ValueKey<String>('sheet-action'),
                    onPressed: () => sheetTaps++,
                    child: const Text('Sheet action'),
                  ),
                ],
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );
    final container = await _pumpPill(tester, extra: openSheet);

    await tester.tap(find.byKey(const ValueKey<String>('open-entity-sheet')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey<String>('entity-sheet')), findsOneWidget);

    // Expand the pill while the sheet is open. Its dismiss barrier belongs to
    // the shell route, so it must stay underneath the modal sheet.
    container.read(quickCreatePillRequestProvider.notifier).state++;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(pillLayerKey), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('sheet-action')));
    await tester.pump();
    expect(
      sheetTaps,
      1,
      reason: 'the entity sheet receives taps above the pill',
    );
    expect(
      find.byKey(pillLayerKey),
      findsOneWidget,
      reason: 'the pill barrier must not intercept the sheet',
    );
  });

  testWidgets('collapsed pill keeps outline border, surface fill and shadow', (
    tester,
  ) async {
    await _pumpPill(tester);
    final scheme = Theme.of(tester.element(find.byKey(pillKey))).colorScheme;
    final container = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.byKey(pillKey),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, scheme.surfaceContainerHigh);
    expect((decoration.border! as Border).top.color, scheme.outline);
    expect(decoration.boxShadow, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded pill card keeps surface fill and shadow', (
    tester,
  ) async {
    await _pumpPill(tester);
    await tester.tap(find.byKey(pillKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final scheme = Theme.of(tester.element(find.byKey(pillCardKey)))
        .colorScheme;
    final container = tester.widget<AnimatedContainer>(find.byKey(pillCardKey));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, scheme.surface);
    expect((decoration.border! as Border).top.color, scheme.outline);
    expect(decoration.boxShadow, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing -p2 selects P2 in the priority wheel', (tester) async {
    await _pumpPill(tester);
    await tester.tap(find.byKey(pillKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The default kind is shared across pill instances, so pin it to task.
    await tester.tap(
      find.byKey(const ValueKey<String>('quick-create-kind-task')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byKey(pillInputKey), 'Buy milk -p2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The wheel value derives from the parsed token, so P2 is the selected
    // row while None is not.
    expect(_wheelRowSelected(tester, 'quick-create-prio-2'), isTrue);
    expect(_wheelRowSelected(tester, 'quick-create-prio-0'), isFalse);
    expect(find.byIcon(Icons.flag), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^P[1-4]$').hasMatch(w.data ?? ''),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting None after typing -p2 clears effective priority', (
    tester,
  ) async {
    _setSize(tester, const Size(500, 800));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    addTearDown(() async => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          taskListsProvider.overrideWith(
            (ref) => Stream.value(const <TaskList>[]),
          ),
          settingsRepositoryProvider.overrideWith(
            (ref) async => SettingsRepository(prefs),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: QuickCreatePill())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(pillKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey<String>('quick-create-kind-task')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byKey(pillInputKey), 'Task -p2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_wheelRowSelected(tester, 'quick-create-prio-2'), isTrue);

    // Selecting None strips the parsed "-p2" token from the text.
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('quick-create-prio-0')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('quick-create-prio-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_wheelRowSelected(tester, 'quick-create-prio-0'), isTrue);
    expect(_wheelRowSelected(tester, 'quick-create-prio-2'), isFalse);
    final field = tester.widget<TextField>(find.byKey(pillInputKey));
    expect(field.controller!.text, 'Task');

    // The saved task carries no priority: effective priority is now None.
    await tester.tap(find.byKey(const ValueKey<String>('quick-create-submit')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final tasks = await db.select(db.tasks).get();
    expect(tasks, hasLength(1));
    expect(tasks.single.priority, 0);
  });
}
