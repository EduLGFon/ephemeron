import 'package:ephemeron/features/stream/presentation/slipped/slipped_trail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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
}
