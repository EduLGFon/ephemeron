import 'package:ephemeron/app/shell/more_sheet.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _sheet({
  List<int> more = const <int>[4, 2],
  ValueChanged<int>? onSelected,
  VoidCallback? onReorder,
  VoidCallback? onSearch,
  VoidCallback? onSettings,
  ValueChanged<MoreCreateAction>? onCreate,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MoreSheet(
        more: more,
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
  testWidgets('more sheet renders command center actions', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_sheet());

    expect(find.text('Search everything'), findsOneWidget);
    for (final action in MoreCreateAction.values) {
      expect(
        find.byKey(ValueKey('more-create-${action.name}')),
        findsOneWidget,
      );
    }
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Customize navigation'), findsOneWidget);
    expect(find.text('Countdowns'), findsOneWidget);
    expect(find.text('Matrix'), findsOneWidget);
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
        onSelected: (idx) => selected = idx,
        onReorder: () => reorders++,
        onSearch: () => searches++,
        onSettings: () => settings++,
        onCreate: (action) => created = action,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('more-search')));
    await tester.tap(find.byKey(const ValueKey('more-create-task')));
    await tester.tap(find.byKey(const ValueKey('more-settings')));
    await tester.tap(find.text('Customize navigation'));
    await tester.tap(find.text('Countdowns'));
    await tester.pump();

    expect(searches, 1);
    expect(created, MoreCreateAction.task);
    expect(settings, 1);
    expect(reorders, 1);
    expect(selected, 4);
  });

  testWidgets('more sheet uses three columns on a 320dp screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_sheet());

    expect(tester.takeException(), isNull);
    final keys = <String>['task', 'event', 'note', 'habit', 'countdown'];
    final tops = <double>[
      for (final key in keys)
        tester.getTopLeft(find.byKey(ValueKey('more-create-$key'))).dy,
    ];
    expect(tops[0], tops[1]);
    expect(tops[1], tops[2]);
    expect(tops[3], tops[4]);
    expect(tops[3], greaterThan(tops[2]));
  });

  test(
    'default navigation order leads with Calendar, Tasks and Notes',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = SettingsRepository(await SharedPreferences.getInstance());
      expect(repo.navOrder, <int>[0, 1, 6, 3, 5, 4, 2]);
    },
  );
}
