import 'package:ephemeron/app/shell/adaptive_shell.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<int> primary,
  List<int> secondary = const <int>[5, 6, 7],
  int currentIndex = 0,
  double textScale = 1,
  ValueChanged<int>? onSelected,
  VoidCallback? onMore,
  VoidCallback? onSettings,
  VoidCallback? onQuickAdd,
  Widget? content,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: AdaptiveShell(
        currentIndex: currentIndex,
        content: content ?? const Center(child: Text('Body')),
        primary: primary,
        secondary: secondary,
        onDestinationSelected: onSelected ?? (_) {},
        onMore: onMore ?? () {},
        onSettings: onSettings ?? () {},
        onQuickAdd: onQuickAdd ?? () {},
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

void main() {
  testWidgets('compact width uses bottom navigation and a reachable FAB', (
    tester,
  ) async {
    _setSize(tester, const Size(400, 800));
    await tester.pumpWidget(_harness(primary: const <int>[0, 1, 2, 3, 4]));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
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

  testWidgets('320dp at 200% text does not overflow', (tester) async {
    _setSize(tester, const Size(320, 640));
    await tester.pumpWidget(
      _harness(primary: const <int>[0, 1, 2, 3, 4], textScale: 2),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
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
    await tester.pumpAndSettle();
    expect(find.text('Pushed body'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
