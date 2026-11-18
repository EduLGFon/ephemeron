import 'package:ephemeron/app/shell/adaptive_shell.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<int> primary,
  List<int> secondary = const <int>[5, 6, 7],
  int currentIndex = 0,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  ValueChanged<int>? onSelected,
  VoidCallback? onMore,
  VoidCallback? onSettings,
  VoidCallback? onQuickAdd,
  Widget? content,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        padding: padding,
      ),
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
      await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    expect(find.text('Pushed body'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
