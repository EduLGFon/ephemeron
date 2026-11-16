import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/day/day_canvas.dart';
import 'package:ephemeron/features/stream/presentation/day/day_gestures.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('culled count exact for 2000 marks', (tester) async {
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
    expect(culled, 8);
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
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
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

  testWidgets('setViewportHeight from layout no exception', (tester) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(999);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 200,
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
    expect(vp.viewportHeight, 200.0);
  });

  testWidgets('semantics node per visible mark', (tester) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    final marks = [
      StreamDayMark(
        id: 'm0',
        kind: StreamDayMarkKind.event,
        startMs: 0,
        endMs: 60 * 60 * 1000,
        title: 'alpha',
        colorArgb: 0xFF000000,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: DayCanvas(
              viewport: vp,
              marks: marks,
              timeFormatter: (ms) => 'T$ms',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final root = tester.getSemantics(find.byType(MaterialApp));
    final labels = <String>[];
    void collect(SemanticsNode n) {
      if (n.label.isNotEmpty) labels.add(n.label);
      n.visitChildren((c) {
        collect(c);
        return true;
      });
    }

    collect(root);
    expect(labels.any((l) => l.contains('alpha')), isTrue);
  });

  testWidgets('pan by touch changes offset and repaints', (tester) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    int paints = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: DayGestureRegion(
              viewport: vp,
              child: DayCanvas(
                viewport: vp,
                marks: const [],
                timeFormatter: (ms) => '$ms',
                onPaint: () => paints++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final before = vp.offsetPx;
    final beforePaints = paints;
    await tester.drag(find.byType(DayCanvas), const Offset(0, -80));
    await tester.pump();
    expect(vp.offsetPx, isNot(before));
    expect(paints, greaterThan(beforePaints));
  });

  testWidgets('pinch changes zoom and repaints', (tester) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    int paints = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: DayGestureRegion(
              viewport: vp,
              child: DayCanvas(
                viewport: vp,
                marks: const [],
                timeFormatter: (ms) => '$ms',
                onPaint: () => paints++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final beforeMpp = vp.minutesPerPixel;
    final beforePaints = paints;
    final g1 = await tester.startGesture(const Offset(100, 200));
    final g2 = await tester.startGesture(const Offset(220, 200));
    await tester.pump();
    await g1.moveBy(const Offset(0, -30));
    await g2.moveBy(const Offset(0, 30));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pump();
    expect(vp.minutesPerPixel, isNot(beforeMpp));
    expect(paints, greaterThan(beforePaints));
  });

  testWidgets('ticker only active during momentum', (tester) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: DayGestureRegion(
              viewport: vp,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final state = tester.state<State<DayGestureRegion>>(
      find.byType(DayGestureRegion),
    );
    final dynamic dyn = state;
    expect(dyn.tickerIsActive, isFalse);
  });

  testWidgets('onGestureEnd fires once per drag', (tester) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    int ends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: DayGestureRegion(
              viewport: vp,
              onGestureEnd: () => ends++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(DayGestureRegion), const Offset(0, -80));
    await tester.pump();
    expect(ends, 1);
  });

  testWidgets('wheel scroll down moves later in time', (tester) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: DayGestureRegion(
              viewport: vp,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final before = vp.offsetPx;
    GestureBinding.instance.handlePointerEvent(
      PointerScrollEvent(
        timeStamp: Duration.zero,
        position: const Offset(180, 200),
        scrollDelta: const Offset(0, 50),
        device: 1,
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();
    expect(vp.offsetPx, greaterThan(before));
  });

  testWidgets('canvas inside non-zero offset (focal stability)', (
    tester,
  ) async {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 60),
              SizedBox(
                width: 360,
                height: 340,
                child: DayGestureRegion(
                  viewport: vp,
                  child: DayCanvas(
                    viewport: vp,
                    marks: const [],
                    timeFormatter: (ms) => '$ms',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
