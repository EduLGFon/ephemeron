import 'package:ephemeron/features/stream/application/stream_ambient.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/countdowns/countdown_edge_chips.dart';
import 'package:ephemeron/features/stream/presentation/countdowns/countdown_landmark.dart';
import 'package:ephemeron/features/stream/presentation/countdowns/countdown_landmark_item.dart';
import 'package:ephemeron/features/stream/presentation/stream_day_controller.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_countdown_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fixtures.dart';

import 'package:material_ui/material_ui.dart';

final DateTime _day = DateTime(2026, 11, 17);
final DateTime _now = DateTime(2026, 11, 17, 10);

// The day preset maps 24h to 56px per hour; midnight lands at y = 0.
const double _dayPx = 24 * 56.0;

CountdownLandmarkItem _item(String id, String title, String? dayKey) =>
    CountdownLandmarkItem(id: id, title: title, targetDayKey: dayKey);

StreamTimeViewport _viewport({double height = 800, double offset = 0}) =>
    StreamTimeViewport(baseEpochMs: _day.millisecondsSinceEpoch)
      ..setViewportHeight(height)
      ..setOffset(offset);

StreamDayBodyController _attach(StreamTimeViewport viewport) =>
    StreamDayBodyController()..attach(viewport: viewport, date: _day);

Widget _host({
  required StreamDayBodyController controller,
  required List<CountdownLandmarkItem> items,
  CountdownEdge edge = CountdownEdge.top,
  ValueChanged<String>? onTap,
  VoidCallback? onShowAll,
  Size size = const Size(400, 800),
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      streamCountdownLandmarkItemsProvider.overrideWith(
        (ref) => Stream.value(items),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: StreamCountdownLayer(
                controller: controller,
                day: _day,
                now: _now,
                labelBuilder: (item, days) => 'd$days',
                onTap: onTap ?? (_) {},
                onShowAll: onShowAll ?? () {},
                edge: edge,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('visible countdown renders a landmark at its mapped y', (
    tester,
  ) async {
    final viewport = _viewport(offset: _dayPx - 400);
    final controller = _attach(viewport);
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);

    await tester.pumpWidget(
      _host(
        controller: controller,
        items: [_item('c0', 'Tomorrow', '2026-11-18')],
      ),
    );
    await settle(tester);

    expect(find.byType(CountdownLandmark), findsOneWidget);
    expect(find.byType(CountdownEdgeChips), findsNothing);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('d1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(CountdownLandmark)).dy,
      closeTo(400, 0.5),
    );
  });

  testWidgets('countdowns above and below the viewport render edge chips', (
    tester,
  ) async {
    final viewport = _viewport();
    final controller = _attach(viewport);
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);

    await tester.pumpWidget(
      _host(
        controller: controller,
        items: [
          _item('past', 'Yesterday', '2026-11-16'),
          _item('future', 'Next week', '2026-11-24'),
        ],
      ),
    );
    await settle(tester);

    expect(find.byType(CountdownLandmark), findsNothing);
    expect(find.byType(CountdownEdgeChips), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Next week'), findsOneWidget);
  });

  testWidgets('three out-of-view countdowns show the aggregate', (
    tester,
  ) async {
    final viewport = _viewport();
    final controller = _attach(viewport);
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);

    await tester.pumpWidget(
      _host(
        controller: controller,
        items: [
          _item('a', 'Nearest', '2026-11-18'),
          _item('b', 'Middle', '2026-11-19'),
          _item('c', 'Farthest', '2026-11-20'),
        ],
      ),
    );
    await settle(tester);

    expect(find.text('Nearest'), findsOneWidget);
    expect(find.text('Middle'), findsOneWidget);
    expect(find.text('Farthest'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('tapping a landmark calls onTap with its id', (tester) async {
    final viewport = _viewport();
    final controller = _attach(viewport);
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);
    String? tapped;

    await tester.pumpWidget(
      _host(
        controller: controller,
        items: [_item('today', 'Today', '2026-11-17')],
        onTap: (id) => tapped = id,
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Today'));
    await tester.pump();
    expect(tapped, 'today');
  });

  testWidgets('tapping an edge chip calls onTap with its id', (tester) async {
    final viewport = _viewport();
    final controller = _attach(viewport);
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);
    String? tapped;

    await tester.pumpWidget(
      _host(
        controller: controller,
        items: [_item('future', 'Future', '2026-11-18')],
        onTap: (id) => tapped = id,
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Future'));
    await tester.pump();
    expect(tapped, 'future');
  });

  testWidgets('the aggregate calls onShowAll', (tester) async {
    final viewport = _viewport();
    final controller = _attach(viewport);
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);
    var showAll = 0;

    await tester.pumpWidget(
      _host(
        controller: controller,
        items: [
          _item('a', 'A', '2026-11-18'),
          _item('b', 'B', '2026-11-19'),
          _item('c', 'C', '2026-11-20'),
        ],
        onShowAll: () => showAll++,
      ),
    );
    await settle(tester);

    await tester.tap(find.text('+1'));
    await tester.pump();
    expect(showAll, 1);
  });

  testWidgets('scrolling changes which countdowns are in view', (tester) async {
    final viewport = _viewport(offset: _dayPx - 400);
    final controller = _attach(viewport);
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);

    await tester.pumpWidget(
      _host(
        controller: controller,
        items: [_item('c0', 'Tomorrow', '2026-11-18')],
      ),
    );
    await settle(tester);
    expect(find.byType(CountdownLandmark), findsOneWidget);
    expect(find.byType(CountdownEdgeChips), findsNothing);

    viewport.setOffset(0);
    await tester.pump();

    expect(find.byType(CountdownLandmark), findsNothing);
    expect(find.byType(CountdownEdgeChips), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
  });

  testWidgets('invalid and missing targets are skipped', (tester) async {
    final viewport = _viewport();
    final controller = _attach(viewport);
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);

    await tester.pumpWidget(
      _host(
        controller: controller,
        items: [
          _item('bad-day', 'Bad day', '2026-02-30'),
          _item('bad-key', 'Bad key', 'nope'),
          const CountdownLandmarkItem(id: 'none', title: 'No target'),
          _item('ok', 'Valid', '2026-11-17'),
        ],
      ),
    );
    await settle(tester);

    expect(find.byType(CountdownLandmark), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);
    expect(find.text('Bad day'), findsNothing);
    expect(find.text('Bad key'), findsNothing);
    expect(find.text('No target'), findsNothing);
    expect(find.byType(CountdownEdgeChips), findsNothing);
  });

  testWidgets('empty list renders nothing', (tester) async {
    final viewport = _viewport();
    final controller = _attach(viewport);
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);

    await tester.pumpWidget(
      _host(controller: controller, items: const <CountdownLandmarkItem>[]),
    );
    await settle(tester);

    expect(find.byType(CountdownLandmark), findsNothing);
    expect(find.byType(CountdownEdgeChips), findsNothing);
  });

  testWidgets('no overflow at 320 dp and 2.0 scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final viewport = _viewport(height: 600);
    final controller = _attach(viewport);
    addTearDown(controller.dispose);
    addTearDown(viewport.dispose);

    await tester.pumpWidget(
      _host(
        controller: controller,
        size: const Size(320, 600),
        textScale: 2,
        items: [
          _item(
            'today',
            'A long countdown title that should fit',
            '2026-11-17',
          ),
          _item('a', 'Another long countdown title', '2026-11-18'),
          _item('b', 'One more long countdown title', '2026-11-19'),
          _item('c', 'Yet another long countdown title', '2026-11-20'),
        ],
      ),
    );
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(CountdownLandmark), findsOneWidget);
    expect(find.byType(CountdownEdgeChips), findsOneWidget);
  });
}
