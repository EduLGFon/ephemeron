import 'package:ephemeron/app/shell/more_sheet.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _sheet({
  List<int> secondary = const <int>[5, 6, 7],
  ValueChanged<int>? onSelected,
  VoidCallback? onReorder,
  VoidCallback? onSettings,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MoreSheet(
        secondary: secondary,
        onSelected: onSelected ?? (_) {},
        onReorder: onReorder ?? () {},
        onSettings: onSettings ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets(
    'more sheet renders secondary destinations without create actions',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_sheet());

      expect(find.text('Search everything'), findsNothing);
      expect(find.byKey(const ValueKey<String>('more-search')), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('more-create-task')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('more-settings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('more-reorder')),
        findsOneWidget,
      );
      expect(find.text('Countdowns'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Matrix'), findsOneWidget);
      // Stream is opt-in: not in the default secondary list.
      expect(find.byKey(const ValueKey<String>('more-stream')), findsNothing);
    },
  );

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

    var settings = 0;
    var reorders = 0;
    int? selected;

    await tester.pumpWidget(
      _sheet(
        onSelected: (value) => selected = value,
        onReorder: () => reorders++,
        onSettings: () => settings++,
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('more-settings')));
    await tester.tap(find.byKey(const ValueKey<String>('more-reorder')));
    await tester.tap(find.text('Countdowns'));
    await tester.pump();

    expect(settings, 1);
    expect(reorders, 1);
    expect(selected, 5);
  });

  testWidgets('more sheet renders on a 320dp screen at 200% text', (
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
              onSettings: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('more-settings')), findsOneWidget);
  });

  test('default nav order is the full destination order', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = SettingsRepository(await SharedPreferences.getInstance());
    expect(repo.navOrderV2, <int>[0, 1, 2, 3, 4, 5, 6, 7, 8]);
  });
}
