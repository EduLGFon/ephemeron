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

Future<void> _jumpWheel(WidgetTester tester, String wheelKey, int index) async {
  final wheel = tester.widget<ListWheelScrollView>(
    find.descendant(
      of: find.byKey(ValueKey<String>(wheelKey)),
      matching: find.byType(ListWheelScrollView),
    ),
  );
  (wheel.controller! as FixedExtentScrollController).jumpToItem(index);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('entity wheel scroll changes kind and hint without modal', (
    tester,
  ) async {
    await _pumpPill(tester);
    await _openPill(tester);

    await _jumpWheel(tester, 'quick-create-kind-wheel', 2);
    expect(find.byType(BottomSheet), findsNothing);

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('quick-create-kind-label')),
          )
          .data,
      'Type: Habit',
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
    'priority wheel scroll updates label/icon and typing -p2 stays source',
    (tester) async {
      await _pumpPill(tester);
      await _openPill(tester);

      await _jumpWheel(tester, 'quick-create-prio-wheel', 1);
      expect(find.byType(BottomSheet), findsNothing);

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('quick-create-prio-label')),
            )
            .data,
        'Priority: P1',
      );
      final p1Icon = tester.widget<Icon>(
        find.byKey(const ValueKey<String>('quick-create-prio-icon')),
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
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('quick-create-prio-label')),
            )
            .data,
        'Priority: P2',
      );
      final p2Icon = tester.widget<Icon>(
        find.byKey(const ValueKey<String>('quick-create-prio-icon')),
      );
      expect(
        p2Icon.color,
        styleForVisualPriority(2).foreground(ThemeData.light().brightness),
      );
    },
  );

  testWidgets('list wheel scroll selects list values inline', (tester) async {
    await _pumpPill(tester, lists: <TaskList>[_list('l1', 'Work')]);
    await _openPill(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('quick-create-list-wheel')),
    );
    await tester.pumpAndSettle();
    await _jumpWheel(tester, 'quick-create-list-wheel', 1);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('quick-create-list-label')),
          )
          .data,
      'List: Work',
    );

    await _jumpWheel(tester, 'quick-create-list-wheel', 0);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('quick-create-list-label')),
          )
          .data,
      'List: No list',
    );
  });

  testWidgets('time wheels scroll updates time label without modal', (
    tester,
  ) async {
    await _pumpPill(tester);
    await _openPill(tester);

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('quick-create-time-label')),
          )
          .data,
      contains('Time:'),
    );

    await _jumpWheel(tester, 'quick-create-time-hour-wheel', 9);
    await _jumpWheel(tester, 'quick-create-time-minute-wheel', 30);
    expect(find.byType(BottomSheet), findsNothing);

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('quick-create-time-label')),
          )
          .data,
      'Time: 09:30',
    );
  });
}
