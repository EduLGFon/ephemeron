import 'package:ephemeron/features/stream/presentation/countdowns/countdown_landmark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_fixtures.dart';

void main() {
  testWidgets('label from formatter is shown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownLandmark(
            id: 'c1',
            title: 'Exam',
            label: '23 days',
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('23 days'), findsOneWidget);
    expect(find.text('Exam'), findsOneWidget);
  });

  testWidgets('tap calls onTap with id', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownLandmark(
            id: 'c2',
            title: 'Trip',
            label: '5 days',
            onTap: (id) => tapped = id,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CountdownLandmark));
    await tester.pump();
    expect(tapped, 'c2');
  });

  testWidgets('number tween disabled under reduce motion', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: CountdownLandmark(
              id: 'c3',
              title: 'X',
              label: '1 day',
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('long title no overflow at 320dp and 2.0 scale', (tester) async {
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
              child: CountdownLandmark(
                id: 'c4',
                title: 'A very long countdown title that should ellipsize instead of overflowing the available width',
                label: '23 days',
                onTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantics present', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountdownLandmark(
            id: 'c5',
            title: 'Event',
            label: '2 days',
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(Semantics), findsWidgets);
  });
}
