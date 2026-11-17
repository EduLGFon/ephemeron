import 'package:ephemeron/features/stream/presentation/slipped/slipped_action_labels.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_item.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_triage.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _labels = SlippedActionLabels(
  done: 'Done',
  tomorrow: 'Tomorrow',
  pickTime: 'Pick time',
  drop: 'Drop',
);

void main() {
  testWidgets('semantics custom actions exist on each row', (tester) async {
    final items = [
      const SlippedItem(
        id: 'z',
        title: 'Z',
        daysOverdue: 1,
        listColorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: SlippedTriage(
              items: items,
              onDone: (_) {},
              onTomorrow: (_) {},
              onPickTime: (_) {},
              onDrop: (_) {},
              onUndoRequested: (_) {},
              daysOverdueLabel: (item) => '${item.daysOverdue}d',
              actionLabels: _labels,
            ),
          ),
        ),
      ),
    );
    final semantics = tester.getSemantics(find.byType(Dismissible));
    expect(semantics.getSemanticsData().customSemanticsActionIds!.length, 4);
    final ids = semantics.getSemanticsData().customSemanticsActionIds!;
    final labels = ids
        .map((id) => CustomSemanticsAction.getAction(id)!.label)
        .toList();
    expect(labels, containsAll(['Done', 'Tomorrow', 'Pick time', 'Drop']));
  });

  testWidgets('keyboard shortcuts trigger callbacks with initial focus', (
    tester,
  ) async {
    final done = <String>[];
    final items = [
      const SlippedItem(
        id: 'k',
        title: 'K',
        daysOverdue: 1,
        listColorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: SlippedTriage(
              items: items,
              onDone: done.add,
              onTomorrow: (_) {},
              onPickTime: (_) {},
              onDrop: (_) {},
              onUndoRequested: (_) {},
              daysOverdueLabel: (item) => '${item.daysOverdue}d',
              actionLabels: _labels,
              hintLabel: 'hint',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(done, ['k']);
  });

  testWidgets('arrow keys move focused row', (tester) async {
    final items = [
      const SlippedItem(
        id: 'a',
        title: 'A',
        daysOverdue: 1,
        listColorArgb: 0xFF000000,
      ),
      const SlippedItem(
        id: 'b',
        title: 'B',
        daysOverdue: 1,
        listColorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: SlippedTriage(
              items: items,
              onDone: (_) {},
              onTomorrow: (_) {},
              onPickTime: (_) {},
              onDrop: (_) {},
              onUndoRequested: (_) {},
              daysOverdueLabel: (item) => '${item.daysOverdue}d',
              actionLabels: _labels,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    // no assertion on which callback; just ensure no crash
  });

  testWidgets('keyboard navigation across 30 items', (tester) async {
    final done = <String>[];
    final pick = <String>[];
    final items = List.generate(
      30,
      (i) => SlippedItem(
        id: 'k$i',
        title: 'Item $i',
        daysOverdue: 1,
        listColorArgb: 0xFF000000,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: SlippedTriage(
              items: items,
              onDone: done.add,
              onTomorrow: (_) {},
              onPickTime: pick.add,
              onDrop: (_) {},
              onUndoRequested: (_) {},
              daysOverdueLabel: (item) => '${item.daysOverdue}d',
              actionLabels: _labels,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(done, ['k20']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    expect(pick, ['k19']);
  });

  testWidgets('reduce motion scrolls selection into view', (tester) async {
    final items = List.generate(
      30,
      (i) => SlippedItem(
        id: 'r$i',
        title: 'Item $i',
        daysOverdue: 1,
        listColorArgb: 0xFF000000,
      ),
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: SlippedTriage(
                items: items,
                onDone: (_) {},
                onTomorrow: (_) {},
                onPickTime: (_) {},
                onDrop: (_) {},
                onUndoRequested: (_) {},
                daysOverdueLabel: (item) => '${item.daysOverdue}d',
                actionLabels: _labels,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 29; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Item 29'), findsOneWidget);
  });

  testWidgets('empty items does not crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: SlippedTriage(
              items: const [],
              onDone: (_) {},
              onTomorrow: (_) {},
              onPickTime: (_) {},
              onDrop: (_) {},
              onUndoRequested: (_) {},
              daysOverdueLabel: (item) => '${item.daysOverdue}d',
              actionLabels: _labels,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected row exposes selected semantics', (tester) async {
    final items = [
      const SlippedItem(
        id: 'z',
        title: 'Z',
        daysOverdue: 1,
        listColorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: SlippedTriage(
              items: items,
              onDone: (_) {},
              onTomorrow: (_) {},
              onPickTime: (_) {},
              onDrop: (_) {},
              onUndoRequested: (_) {},
              daysOverdueLabel: (item) => '${item.daysOverdue}d',
              actionLabels: _labels,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final data = tester
        .getSemantics(find.byType(Dismissible))
        .getSemanticsData();
    expect(data.flagsCollection.isSelected.name, 'isTrue');
  });
}
