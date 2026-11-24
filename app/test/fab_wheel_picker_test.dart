import 'package:ephemeron/app/shell/quick_create_pill.dart';
import 'package:ephemeron/core/design/components/app_wheel.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<ProviderContainer> _pumpPill(
  WidgetTester tester, {
  Size size = const Size(500, 900),
  List<TaskList> lists = const <TaskList>[],
}) async {
  QuickCreatePill.debugResetLastKind();
  _setSize(tester, size);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      taskListsProvider.overrideWith((ref) => Stream.value(lists)),
      settingsRepositoryProvider.overrideWith(
        (ref) async => SettingsRepository(prefs),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: Center(child: QuickCreatePill())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

TaskList _list(String id, String name) => TaskList(
  id: id,
  name: name,
  sortOrder: 0,
  createdAt: 0,
  updatedAt: 0,
  dirty: false,
);

Future<void> _openPill(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('quick-create-pill')));
  await tester.pumpAndSettle();
}

Finder _kindButton() =>
    find.byKey(const ValueKey<String>('quick-create-kind-button'));
Finder _prioButton() =>
    find.byKey(const ValueKey<String>('quick-create-prio-button'));
Finder _listButton() =>
    find.byKey(const ValueKey<String>('quick-create-list-button'));
Finder _timeButton() =>
    find.byKey(const ValueKey<String>('quick-create-time-button'));

void main() {
  testWidgets('entity picker applies Habit on Done and updates button/hint', (
    tester,
  ) async {
    await _pumpPill(tester);
    await _openPill(tester);

    expect(_kindButton(), findsOneWidget);
    await tester.tap(_kindButton());
    await tester.pumpAndSettle();

    expect(find.text('Type'), findsWidgets);
    final kindWheel = tester.widget<ListWheelScrollView>(
      find.byType(ListWheelScrollView),
    );
    (kindWheel.controller! as FixedExtentScrollController).jumpToItem(2);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('quick-create-kind-habit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: _kindButton(), matching: find.text('Habit')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('quick-create-input')),
          )
          .decoration
          ?.hintText,
      'Meditate every day',
    );
  });

  testWidgets(
    'priority picker applies P1 on Done and text token stays source',
    (tester) async {
      await _pumpPill(tester);
      await _openPill(tester);

      await tester.tap(_prioButton());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('quick-create-prio-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: _prioButton(), matching: find.text('P1')),
        findsOneWidget,
      );
      final p1Icon = tester.widget<Icon>(
        find.descendant(
          of: _prioButton(),
          matching: find.byKey(
            const ValueKey<String>('quick-create-prio-icon'),
          ),
        ),
      );
      expect(
        p1Icon.color,
        styleForVisualPriority(1).foreground(ThemeData.light().brightness),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('quick-create-input')),
        'task -p2',
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: _prioButton(), matching: find.text('P2')),
        findsOneWidget,
      );
      final p2Icon = tester.widget<Icon>(
        find.descendant(
          of: _prioButton(),
          matching: find.byKey(
            const ValueKey<String>('quick-create-prio-icon'),
          ),
        ),
      );
      expect(
        p2Icon.color,
        styleForVisualPriority(2).foreground(ThemeData.light().brightness),
      );
    },
  );

  testWidgets('list picker shows No list option', (tester) async {
    await _pumpPill(tester, lists: <TaskList>[_list('l1', 'Work')]);
    await _openPill(tester);

    await tester.ensureVisible(_listButton());
    await tester.pumpAndSettle();
    await tester.tap(_listButton());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-create-list-none')),
      findsOneWidget,
    );
    expect(find.text('No list'), findsWidgets);
  });

  testWidgets('time picker applies selected value on Done', (tester) async {
    await _pumpPill(tester);
    await _openPill(tester);

    expect(
      find.descendant(of: _timeButton(), matching: find.text('Time')),
      findsOneWidget,
    );

    await tester.tap(_timeButton());
    await tester.pumpAndSettle();

    final wheels = tester
        .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
        .toList();
    expect(wheels, hasLength(2));
    (wheels[0].controller! as FixedExtentScrollController).jumpToItem(9);
    (wheels[1].controller! as FixedExtentScrollController).jumpToItem(30);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: _timeButton(), matching: find.text('Time')),
      findsNothing,
    );
    final timeLabel = tester.widget<Text>(
      find.descendant(of: _timeButton(), matching: find.byType(Text)).first,
    );
    expect(timeLabel.data, contains('30'));
    expect(timeLabel.data, contains('9'));
  });
}
