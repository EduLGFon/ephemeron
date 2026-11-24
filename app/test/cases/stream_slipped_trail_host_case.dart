import 'dart:async';

import 'package:ephemeron/features/stream/application/stream_slipped_data.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_item.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_trail.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_slipped_trail_host.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_fixtures.dart';

SlippedItem _item(int i) => SlippedItem(
  id: 's$i',
  title: 'Slipped $i',
  daysOverdue: i + 1,
  listColorArgb: 0xFF336699,
);

List<SlippedItem> _items(int count) => List<SlippedItem>.generate(count, _item);

Widget _app({
  Stream<List<SlippedItem>>? stream,
  List<SlippedItem> items = const <SlippedItem>[],
  VoidCallback? onOpenTriage,
  double width = 400,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      streamSlippedItemsProvider.overrideWith(
        (ref) => stream ?? Stream.value(items),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: SizedBox(
              width: width,
              child: StreamSlippedTrailHost(
                onOpenTriage: onOpenTriage ?? () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('empty provider renders nothing', (tester) async {
    await tester.pumpWidget(_app());
    await settle(tester);
    expect(find.byType(SlippedTrail), findsNothing);
    expect(find.textContaining('slipped'), findsNothing);
  });

  testWidgets('one item shows the singular label', (tester) async {
    await tester.pumpWidget(_app(items: _items(1)));
    await settle(tester);
    expect(find.text('1 slipped'), findsOneWidget);
  });

  testWidgets('five items show the plural label and matching count', (
    tester,
  ) async {
    await tester.pumpWidget(_app(items: _items(5)));
    await settle(tester);
    expect(find.text('5 slipped'), findsOneWidget);
    final trail = tester.widget<SlippedTrail>(find.byType(SlippedTrail));
    expect(trail.count, 5);
  });

  testWidgets('tapping the pill opens triage once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(items: _items(3), onOpenTriage: () => taps++));
    await settle(tester);
    await tester.tap(find.text('3 slipped'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('provider updates change the count', (tester) async {
    final controller = StreamController<List<SlippedItem>>();
    addTearDown(controller.close);
    await tester.pumpWidget(_app(stream: controller.stream));
    await tester.pump();

    controller.add(_items(2));
    await settle(tester);
    expect(find.text('2 slipped'), findsOneWidget);

    controller.add(_items(4));
    await settle(tester);
    expect(find.text('4 slipped'), findsOneWidget);
    expect(find.text('2 slipped'), findsNothing);
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    await tester.pumpWidget(_app(items: _items(5), width: 320, textScale: 2.0));
    await settle(tester);
    expect(find.text('5 slipped'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
