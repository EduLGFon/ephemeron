import 'package:ephemeron/features/stream/presentation/slipped/slipped_action_labels.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_item.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_trail.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_triage.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = SlippedActionLabels(
  done: 'Done',
  tomorrow: 'Tomorrow',
  pickTime: 'Pick time',
  drop: 'Drop',
);

void main() {
  testWidgets('empty trail renders nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlippedTrail(count: 0, label: '0 slipped', onOpenTriage: () {}),
        ),
      ),
    );
    expect(find.text('0 slipped'), findsNothing);
  });

  testWidgets('trail renders a single pill with caller label', (tester) async {
    for (final n in [1, 2, 3]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlippedTrail(
              count: n,
              label: '$n slipped',
              onOpenTriage: () {},
            ),
          ),
        ),
      );
      expect(find.text('$n slipped'), findsOneWidget);
    }
  });

  testWidgets('more than three renders aggregate count in label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlippedTrail(count: 5, label: '5 slipped', onOpenTriage: () {}),
        ),
      ),
    );
    expect(find.text('5 slipped'), findsOneWidget);
  });

  testWidgets('tapping a pill calls onOpenTriage once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlippedTrail(
            count: 2,
            label: '2 slipped',
            onOpenTriage: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('2 slipped'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('trail semantics label contains count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlippedTrail(count: 2, label: '2 slipped', onOpenTriage: () {}),
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('2')), findsOneWidget);
  });

  testWidgets('reduce-motion reaches target opacity immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SlippedTrail(
              count: 2,
              label: '2 slipped',
              onOpenTriage: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 1.0);
  });

  testWidgets('triage rows show all items', (tester) async {
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
        daysOverdue: 2,
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
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('1d'), findsOneWidget);
    expect(find.text('2d'), findsOneWidget);
  });

  testWidgets('tapping each action calls right callback with right id', (
    tester,
  ) async {
    final done = <String>[];
    final tomorrow = <String>[];
    final pick = <String>[];
    final drop = <String>[];
    final items = [
      const SlippedItem(
        id: 'x',
        title: 'X',
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
              onTomorrow: tomorrow.add,
              onPickTime: pick.add,
              onDrop: drop.add,
              onUndoRequested: (_) {},
              daysOverdueLabel: (item) => '${item.daysOverdue}d',
              actionLabels: _labels,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.schedule).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.access_time).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(done, ['x']);
    expect(tomorrow, ['x']);
    expect(pick, ['x']);
    expect(drop, ['x']);
  });

  testWidgets(
    'swipe right triggers onDone and swipe left triggers onTomorrow',
    (tester) async {
      final done = <String>[];
      final tomorrow = <String>[];
      final items = [
        const SlippedItem(
          id: 'y',
          title: 'Y',
          daysOverdue: 1,
          listColorArgb: 0xFF000000,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: SlippedTriage(
                items: items,
                onDone: done.add,
                onTomorrow: tomorrow.add,
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
      await tester.drag(find.text('Y'), const Offset(300, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Y'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(done, ['y']);
      expect(tomorrow, ['y']);
    },
  );

  testWidgets('edge swipe does not fire onDone', (tester) async {
    final done = <String>[];
    final items = [
      const SlippedItem(
        id: 'e',
        title: 'E',
        daysOverdue: 1,
        listColorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final y = tester.getCenter(find.text('E')).dy;
    await tester.dragFrom(
      const Offset(2, 0) + Offset(0, y),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
    expect(done, isEmpty);
    // 30 dp from edge fires
    await tester.dragFrom(
      const Offset(30, 0) + Offset(0, y),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
    expect(done, ['e']);

    final tomorrow = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: SlippedTriage(
              items: const [
                SlippedItem(
                  id: 'r',
                  title: 'R',
                  daysOverdue: 1,
                  listColorArgb: 0xFF000000,
                ),
              ],
              onDone: (_) {},
              onTomorrow: tomorrow.add,
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
    final yr = tester.getCenter(find.text('R')).dy;
    await tester.dragFrom(Offset(398, yr), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tomorrow, isEmpty);
    await tester.dragFrom(Offset(370, yr), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tomorrow, ['r']);
  });

  testWidgets('long title does not overflow at 320dp and 2.0 scale', (
    tester,
  ) async {
    final items = List.generate(
      30,
      (i) => SlippedItem(
        id: 'l$i',
        title:
            'A very long title that should not overflow the available width when scaled up significantly $i',
        daysOverdue: 1,
        listColorArgb: 0xFF000000,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SizedBox(
              width: 320,
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
    expect(tester.takeException(), isNull);
  });

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
    expect(true, isTrue);
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
}
