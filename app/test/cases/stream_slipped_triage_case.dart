import 'package:ephemeron/features/stream/presentation/slipped/slipped_action_labels.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_item.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_triage.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_fixtures.dart';

const _labels = SlippedActionLabels(
  done: 'Done',
  tomorrow: 'Tomorrow',
  pickTime: 'Pick time',
  drop: 'Drop',
);

void main() {
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
    await settle(tester);
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
      await settle(tester);
      await tester.drag(find.text('Y'), const Offset(300, 0));
      await settle(tester);
      await tester.drag(find.text('Y'), const Offset(-300, 0));
      await settle(tester);
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
    await settle(tester);
    final y = tester.getCenter(find.text('E')).dy;
    await tester.dragFrom(
      const Offset(2, 0) + Offset(0, y),
      const Offset(300, 0),
    );
    await settle(tester);
    expect(done, isEmpty);
    // 30 dp from edge fires
    await tester.dragFrom(
      const Offset(30, 0) + Offset(0, y),
      const Offset(300, 0),
    );
    await settle(tester);
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
    await settle(tester);
    final yr = tester.getCenter(find.text('R')).dy;
    await tester.dragFrom(Offset(398, yr), const Offset(-300, 0));
    await settle(tester);
    expect(tomorrow, isEmpty);
    await tester.dragFrom(Offset(370, yr), const Offset(-300, 0));
    await settle(tester);
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
    await settle(tester);
    for (var i = 0; i < 29; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await settle(tester);
    expect(find.textContaining('significantly 29'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
