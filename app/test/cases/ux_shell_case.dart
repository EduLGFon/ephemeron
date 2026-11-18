import 'package:ephemeron/app/shell/more_sheet.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _sheet({
  List<int> secondary = const <int>[5, 6, 7],
  ValueChanged<int>? onSelected,
  VoidCallback? onReorder,
  VoidCallback? onSearch,
  VoidCallback? onSettings,
  ValueChanged<MoreCreateAction>? onCreate,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MoreSheet(
        secondary: secondary,
        onSelected: onSelected ?? (_) {},
        onReorder: onReorder ?? () {},
        onSearch: onSearch ?? () {},
        onSettings: onSettings ?? () {},
        onCreate: onCreate ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('more sheet renders create actions and secondary destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_sheet());

    expect(find.text('Search everything'), findsOneWidget);
    for (final action in MoreCreateAction.values) {
      expect(
        find.byKey(ValueKey<String>('more-create-${action.name}')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey<String>('more-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('more-reorder')), findsOneWidget);
    expect(find.text('Countdowns'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Matrix'), findsOneWidget);
    // Stream is opt-in: not in the default secondary list.
    expect(find.byKey(const ValueKey<String>('more-stream')), findsNothing);
  });

  testWidgets('more sheet shows Stream only when it is in the secondary list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? selected;
    await tester.pumpWidget(
      _sheet(
        secondary: const <int>[5, 6, 7, 8],
        onSelected: (value) => selected = value,
      ),
    );

    expect(find.byKey(const ValueKey<String>('more-stream')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('more-stream')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('more-stream')));
    await tester.pump();
    expect(selected, 8);
  });

  testWidgets('more sheet fires its callbacks', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var searches = 0;
    var settings = 0;
    var reorders = 0;
    int? selected;
    MoreCreateAction? created;

    await tester.pumpWidget(
      _sheet(
        onSelected: (value) => selected = value,
        onReorder: () => reorders++,
        onSearch: () => searches++,
        onSettings: () => settings++,
        onCreate: (action) => created = action,
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('more-search')));
    await tester.tap(find.byKey(const ValueKey<String>('more-create-task')));
    await tester.tap(find.byKey(const ValueKey<String>('more-settings')));
    await tester.tap(find.byKey(const ValueKey<String>('more-reorder')));
    await tester.tap(find.text('Countdowns'));
    await tester.pump();

    expect(searches, 1);
    expect(created, MoreCreateAction.task);
    expect(settings, 1);
    expect(reorders, 1);
    expect(selected, 5);
  });

  testWidgets('more sheet uses three columns on a 320dp screen at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: MoreSheet(
              secondary: const <int>[5, 6, 7, 8],
              onSelected: (_) {},
              onReorder: () {},
              onSearch: () {},
              onSettings: () {},
              onCreate: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final keys = <String>['task', 'event', 'note', 'habit', 'countdown'];
    final tops = <double>[
      for (final key in keys)
        tester.getTopLeft(find.byKey(ValueKey<String>('more-create-$key'))).dy,
    ];
    expect(tops[0], tops[1]);
    expect(tops[1], tops[2]);
    expect(tops[3], tops[4]);
    expect(tops[3], greaterThan(tops[2]));
  });

  test('default primary order is Today through Focus', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.navOrderV2, <int>[0, 1, 2, 3, 4]);
  });
}
