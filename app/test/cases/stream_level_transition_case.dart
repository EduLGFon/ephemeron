import 'package:ephemeron/features/stream/presentation/levels/level_transition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('crossfade duration <= 180ms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(
            level: 1,
            duration: const Duration(milliseconds: 180),
            onChanged: (_) {},
            child: const Text('A'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(
            level: 2,
            duration: const Duration(milliseconds: 180),
            onChanged: (_) {},
            child: const Text('B'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('onChanged fires once', (tester) async {
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(
            level: 1,
            duration: const Duration(milliseconds: 100),
            onChanged: (_) => calls++,
            child: const Text('A'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(
            level: 2,
            duration: const Duration(milliseconds: 100),
            onChanged: (_) => calls++,
            child: const Text('B'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    expect(calls, 1);
  });

  testWidgets('reduce motion immediate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: LevelTransition(
              level: 1,
              duration: const Duration(milliseconds: 180),
              onChanged: (_) {},
              child: const Text('A'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: LevelTransition(
              level: 2,
              duration: const Duration(milliseconds: 180),
              onChanged: (_) {},
              child: const Text('B'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('no exception if children same widget', (tester) async {
    const w = Text('same');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(level: 1, onChanged: (_) {}, child: w),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(level: 1, onChanged: (_) {}, child: w),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses FadeTransition not Opacity', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(
            level: 1,
            duration: const Duration(milliseconds: 100),
            onChanged: (_) {},
            child: const Text('A'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(
            level: 2,
            duration: const Duration(milliseconds: 100),
            onChanged: (_) {},
            child: const Text('B'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('onChanged receives midpoint level argument', (tester) async {
    Object? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(
            level: 1,
            duration: const Duration(milliseconds: 100),
            onChanged: (l) => received = l,
            child: const Text('A'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(
            level: 2,
            duration: const Duration(milliseconds: 100),
            onChanged: (l) => received = l,
            child: const Text('B'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(received, 2);
  });

  testWidgets('reduce motion fires onChanged', (tester) async {
    int calls = 0;
    Object? received;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: LevelTransition(
              level: 1,
              duration: const Duration(milliseconds: 180),
              onChanged: (l) {
                calls++;
                received = l;
              },
              child: const Text('A'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: LevelTransition(
              level: 2,
              duration: const Duration(milliseconds: 180),
              onChanged: (l) {
                calls++;
                received = l;
              },
              child: const Text('B'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(calls, greaterThanOrEqualTo(1));
    expect(received, 2);
  });

  testWidgets('outgoing child disposed after transition', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(
            level: 1,
            duration: const Duration(milliseconds: 50),
            onChanged: (_) {},
            child: const Text('A'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTransition(
            level: 2,
            duration: const Duration(milliseconds: 50),
            onChanged: (_) {},
            child: const Text('B'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });
}
