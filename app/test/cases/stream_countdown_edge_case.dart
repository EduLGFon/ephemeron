import 'package:ephemeron/features/stream/presentation/countdowns/countdown_edge_chips.dart';
import 'package:ephemeron/features/stream/presentation/countdowns/countdown_landmark_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  List<CountdownLandmarkItem> items(int n) => List.generate(
    n,
    (i) => CountdownLandmarkItem(
      id: 'e$i',
      title: 'Event $i',
      targetDayKey: '2026-03-10',
    ),
  );

  testWidgets('zero items renders nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownEdgeChips(
            items: const [],
            edge: CountdownEdge.top,
            labelBuilder: (_) => '1 day',
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(CountdownEdgeChips), findsOneWidget);
    expect(find.text('1 day'), findsNothing);
  });

  testWidgets('one out-of-view item', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownEdgeChips(
            items: items(1),
            edge: CountdownEdge.top,
            labelBuilder: (i) => '1 day',
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Event 0'), findsOneWidget);
  });

  testWidgets('two out-of-view items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownEdgeChips(
            items: items(2),
            edge: CountdownEdge.bottom,
            labelBuilder: (i) => '2 days',
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Event 0'), findsOneWidget);
    expect(find.text('Event 1'), findsOneWidget);
  });

  testWidgets('three items shows aggregate', (tester) async {
    var showAll = 0;
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownEdgeChips(
            items: items(3),
            edge: CountdownEdge.top,
            labelBuilder: (i) => '3 days',
            onTap: (id) => tapped = id,
            onShowAll: () => showAll++,
            aggregateLabel: '+1 more',
          ),
        ),
      ),
    );
    expect(find.text('+1 more'), findsOneWidget);
    await tester.tap(find.text('+1 more'));
    await tester.pump();
    expect(showAll, 1);
    // tapping a chip calls right id
    await tester.tap(find.text('Event 0'));
    await tester.pump();
    expect(tapped, 'e0');
  });

  testWidgets('aggregate appears only above two', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownEdgeChips(
            items: items(2),
            edge: CountdownEdge.top,
            labelBuilder: (i) => '2 days',
            onTap: (_) {},
            aggregateLabel: '+9',
          ),
        ),
      ),
    );
    expect(find.text('+9'), findsNothing);
  });

  testWidgets('no overflow at 320dp and 2.0 scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 200,
              child: CountdownEdgeChips(
                items: items(3),
                edge: CountdownEdge.top,
                labelBuilder: (i) =>
                    'A very long days label that should not overflow',
                onTap: (_) {},
                onShowAll: () {},
                aggregateLabel: '+1 more',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
