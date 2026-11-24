import 'package:ephemeron/core/design/components/app_wheel.dart';
import 'package:ephemeron/core/design/components/wheel_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const List<WheelItem<String>> _items = <WheelItem<String>>[
  WheelItem(value: 'A', label: 'Alpha', key: ValueKey<String>('row-a')),
  WheelItem(value: 'B', label: 'Bravo', key: ValueKey<String>('row-b')),
  WheelItem(value: 'C', label: 'Charlie', key: ValueKey<String>('row-c')),
  WheelItem(value: 'D', label: 'Delta', key: ValueKey<String>('row-d')),
  WheelItem(value: 'E', label: 'Echo', key: ValueKey<String>('row-e')),
];

Widget _app(
  Widget body, {
  double textScale = 1,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: Scaffold(body: Center(child: body)),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

int _selectedItem(WidgetTester tester) {
  final wheel = tester.widget<ListWheelScrollView>(
    find.byType(ListWheelScrollView),
  );
  return (wheel.controller! as FixedExtentScrollController).selectedItem;
}

Iterable<Semantics> _rowSemantics(WidgetTester tester) =>
    tester.widgetList<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.selected != null &&
            widget.properties.label != null,
      ),
    );

void main() {
  testWidgets('renders exactly three rows with a selected center row', (
    tester,
  ) async {
    const extent = 56.0;
    await tester.pumpWidget(
      _app(
        WheelPicker<String>(
          key: const Key('wheel'),
          items: _items,
          value: 'C',
          onChanged: (_) {},
          itemExtent: extent,
          semanticsLabel: 'Letters',
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('wheel'))).height, extent * 3);
    final rows = _rowSemantics(tester).toList();
    expect(rows, hasLength(3));
    expect(
      rows.map((row) => row.properties.label),
      containsAll(<String>['Bravo', 'Charlie', 'Delta']),
    );
    expect(
      rows
          .where((row) => row.properties.selected == true)
          .map((row) => row.properties.label),
      <String>['Charlie'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('external value scrolls to it without reporting a change', (
    tester,
  ) async {
    final changes = <String>[];
    final value = ValueNotifier<String>('A');
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<String>(
          valueListenable: value,
          builder: (context, current, _) => WheelPicker<String>(
            items: _items,
            value: current,
            onChanged: changes.add,
          ),
        ),
      ),
    );
    expect(_selectedItem(tester), 0);

    value.value = 'D';
    await tester.pumpAndSettle();

    expect(_selectedItem(tester), 3);
    expect(changes, isEmpty);
  });

  testWidgets('retargeting an in-flight scroll reports no intermediate value', (
    tester,
  ) async {
    final changes = <String>[];
    final value = ValueNotifier<String>('A');
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<String>(
          valueListenable: value,
          builder: (context, current, _) => WheelPicker<String>(
            items: _items,
            value: current,
            onChanged: changes.add,
          ),
        ),
      ),
    );
    expect(_selectedItem(tester), 0);

    // The first animation is interrupted while the second one is still
    // crossing rows. Only the second completion may release the guard.
    value.value = 'E';
    await tester.pump(const Duration(milliseconds: 1));
    value.value = 'C';
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(_selectedItem(tester), 2);
    expect(changes, isEmpty);
  });

  testWidgets('drag snaps to the next item and reports it', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      _app(
        WheelPicker<String>(items: _items, value: 'C', onChanged: changes.add),
      ),
    );
    expect(_selectedItem(tester), 2);

    await tester.drag(find.byType(ListWheelScrollView), const Offset(0, -56));
    await tester.pumpAndSettle();

    expect(changes, isNotEmpty);
    expect(changes.last, 'D');
    expect(_selectedItem(tester), 3);
  });

  testWidgets('tapping a visible row centers and reports it', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      _app(
        WheelPicker<String>(items: _items, value: 'B', onChanged: changes.add),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('row-c')));
    await tester.pumpAndSettle();

    expect(changes, <String>['C']);
    expect(_selectedItem(tester), 2);
  });

  testWidgets('reduced motion applies the selection immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        WheelPicker<String>(items: _items, value: 'B', onChanged: (_) {}),
        disableAnimations: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('row-c')));
    await tester.pumpAndSettle();

    expect(
      _rowSemantics(tester)
          .where((row) => row.properties.selected == true)
          .map((row) => row.properties.label),
      <String>['Charlie'],
    );
    expect(_selectedItem(tester), 2);
  });

  testWidgets('long labels ellipsize at 200 percent text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        WheelPicker<String>(items: _items, value: 'C', onChanged: (_) {}),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(_rowSemantics(tester), hasLength(3));
  });

  testWidgets('sheet Done returns the pending value', (tester) async {
    String? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showWheelPickerSheet<String>(
                context,
                title: 'Pick a letter',
                items: _items,
                value: 'B',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(WheelPicker<String>), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('row-c')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, 'C');
  });

  testWidgets('sheet Cancel returns null', (tester) async {
    String? result = 'untouched';
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showWheelPickerSheet<String>(
                context,
                title: 'Pick a letter',
                items: _items,
                value: 'B',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(WheelPicker<String>), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
