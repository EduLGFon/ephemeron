import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/day/day_canvas.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('culled count small for 2000 marks', (tester) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    final marks = List.generate(2000, (i) {
      final start = i * 60 * 60 * 1000;
      return StreamDayMark(
        id: 'm$i',
        kind: StreamDayMarkKind.event,
        startMs: start,
        endMs: start + 30 * 60 * 1000,
        title: 't$i',
        colorArgb: 0xFF000000,
      );
    });
    int? culled;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: DayCanvas(
              viewport: vp,
              marks: marks,
              timeFormatter: (ms) => '$ms',
              onCulledCount: (c) => culled = c,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(culled, isNotNull);
    expect(culled!, lessThan(50));
  });

  testWidgets('text scale 2.0 no overflow', (tester) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    final marks = [
      StreamDayMark(
        id: 'm0',
        kind: StreamDayMarkKind.event,
        startMs: 0,
        endMs: 60 * 60 * 1000,
        title: 'a very long title that should ellipsize nicely',
        colorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: DayCanvas(
              viewport: vp,
              marks: marks,
              timeFormatter: (ms) => '$ms',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty marks no exception', (tester) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: DayCanvas(
              viewport: vp,
              marks: const [],
              timeFormatter: (ms) => '$ms',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
