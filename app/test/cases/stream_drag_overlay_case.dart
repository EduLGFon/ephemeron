import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/features/stream/presentation/gestures/drag_mark_overlay.dart';

void main() {
  testWidgets('preview follows pointer and shows formatter time', (
    tester,
  ) async {
    final offset = ValueNotifier<Offset>(const Offset(10, 20));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ValueListenableBuilder<Offset>(
                valueListenable: offset,
                builder: (context, o, _) => DragMarkOverlay(
                  title: 'Title',
                  timeLabel: '12:34',
                  offset: o,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('12:34'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.left, 10);
    expect(positioned.top, 20);

    offset.value = const Offset(30, 40);
    await tester.pump();
    final moved = tester.widget<Positioned>(find.byType(Positioned));
    expect(moved.left, 30);
    expect(moved.top, 40);
  });

  testWidgets('overlay update does not rebuild underlying stream', (
    tester,
  ) async {
    final offset = ValueNotifier<Offset>(const Offset(10, 20));
    var streamBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Builder(
                builder: (context) {
                  streamBuilds++;
                  return const SizedBox(
                    width: 100,
                    height: 100,
                    key: ValueKey('stream'),
                  );
                },
              ),
              ValueListenableBuilder<Offset>(
                valueListenable: offset,
                builder: (context, o, _) => DragMarkOverlay(
                  title: 'Title',
                  timeLabel: '12:34',
                  offset: o,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final before = streamBuilds;
    offset.value = const Offset(30, 40);
    await tester.pump();
    expect(streamBuilds, before);
  });
}
