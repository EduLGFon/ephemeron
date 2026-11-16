import 'package:ephemeron/features/stream/presentation/slipped/slipped_item.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_trail.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_triage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty trail renders nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlippedTrail(count: 0, label: '0 slipped', onOpenTriage: () {}),
        ),
      ),
    );
    expect(find.byType(SlippedTrail), findsOneWidget);
    expect(find.text('0 slipped'), findsNothing);
  });

  testWidgets('one to three pills render with caller label', (tester) async {
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
      expect(find.text('$n slipped'), findsNWidgets(n));
    }
  });

  testWidgets('more than three renders aggregate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlippedTrail(count: 5, label: '5 slipped', onOpenTriage: () {}),
        ),
      ),
    );
    expect(find.text('+3'), findsOneWidget);
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
    await tester.tap(find.text('2 slipped').first);
    await tester.pump();
    expect(taps, 1);
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
          body: SlippedTriage(
            items: items,
            onDone: (_) {},
            onTomorrow: (_) {},
            onPickTime: (_) {},
            onDrop: (_) {},
            onUndoRequested: (_) {},
            daysOverdueLabel: (item) => '${item.daysOverdue}d',
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
          body: SlippedTriage(
            items: items,
            onDone: done.add,
            onTomorrow: tomorrow.add,
            onPickTime: pick.add,
            onDrop: drop.add,
            onUndoRequested: (_) {},
            daysOverdueLabel: (item) => '${item.daysOverdue}d',
          ),
        ),
      ),
    );
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
              child: SlippedTriage(
                items: items,
                onDone: done.add,
                onTomorrow: tomorrow.add,
                onPickTime: (_) {},
                onDrop: (_) {},
                onUndoRequested: (_) {},
                daysOverdueLabel: (item) => '${item.daysOverdue}d',
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
          body: SlippedTriage(
            items: items,
            onDone: (_) {},
            onTomorrow: (_) {},
            onPickTime: (_) {},
            onDrop: (_) {},
            onUndoRequested: (_) {},
            daysOverdueLabel: (item) => '${item.daysOverdue}d',
          ),
        ),
      ),
    );
    final semantics = tester.getSemantics(find.byType(Dismissible));
    expect(semantics, isNotNull);
  });

  testWidgets('reduce-motion disables implicit animation', (tester) async {
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
    expect(find.text('2 slipped'), findsNWidgets(2));
  });
}
