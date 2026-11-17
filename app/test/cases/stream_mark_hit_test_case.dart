import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/mark_hit_test.dart';
import 'package:ephemeron/features/stream/engine/stream_mark_layout.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StreamTimeViewport makeVp() {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    return vp;
  }

  test('hit inside a mark', () {
    final vp = makeVp();
    final marks = [
      StreamDayMark(
        id: 'm0',
        kind: StreamDayMarkKind.event,
        startMs: 0,
        endMs: 60 * 60 * 1000,
        title: 't',
        colorArgb: 0xFF000000,
      ),
    ];
    final layout = layoutMarkColumns([
      const MarkInterval(startMs: 0, endMs: 60 * 60 * 1000, id: 'm0'),
    ]);
    final y = vp.timeToPx(30 * 60 * 1000);
    expect(
      hitTestMark(
        marks: marks,
        layout: layout,
        viewport: vp,
        focalY: y,
        canvasWidth: 360,
        focalX: 100,
      ),
      'm0',
    );
  });

  test('hit inside a gap returns null', () {
    final vp = makeVp();
    final marks = [
      StreamDayMark(
        id: 'm0',
        kind: StreamDayMarkKind.event,
        startMs: 0,
        endMs: 30 * 60 * 1000,
        title: 't',
        colorArgb: 0xFF000000,
      ),
    ];
    final layout = layoutMarkColumns([
      const MarkInterval(startMs: 0, endMs: 30 * 60 * 1000, id: 'm0'),
    ]);
    final y = vp.timeToPx(45 * 60 * 1000);
    expect(
      hitTestMark(
        marks: marks,
        layout: layout,
        viewport: vp,
        focalY: y,
        canvasWidth: 360,
        focalX: 100,
      ),
      isNull,
    );
  });

  test('hit inside an overlapping mark column', () {
    final vp = makeVp();
    final marks = [
      StreamDayMark(
        id: 'a',
        kind: StreamDayMarkKind.event,
        startMs: 0,
        endMs: 60 * 60 * 1000,
        title: 'a',
        colorArgb: 0xFF000000,
      ),
      StreamDayMark(
        id: 'b',
        kind: StreamDayMarkKind.event,
        startMs: 0,
        endMs: 60 * 60 * 1000,
        title: 'b',
        colorArgb: 0xFF000000,
      ),
    ];
    final layout = layoutMarkColumns([
      const MarkInterval(startMs: 0, endMs: 60 * 60 * 1000, id: 'a'),
      const MarkInterval(startMs: 0, endMs: 60 * 60 * 1000, id: 'b'),
    ]);
    final y = vp.timeToPx(30 * 60 * 1000);
    expect(
      hitTestMark(
        marks: marks,
        layout: layout,
        viewport: vp,
        focalY: y,
        canvasWidth: 360,
        focalX: 200,
      ),
      'b',
    );
  });

  test('hit on all-day mark at top slot', () {
    final vp = makeVp();
    final marks = [
      StreamDayMark(
        id: 'allday',
        kind: StreamDayMarkKind.event,
        startMs: 0,
        endMs: 24 * 60 * 60 * 1000,
        title: 'all day',
        colorArgb: 0xFF000000,
        isAllDay: true,
      ),
    ];
    final layout = layoutMarkColumns([
      const MarkInterval(startMs: 0, endMs: 24 * 60 * 60 * 1000, id: 'allday'),
    ]);
    expect(
      hitTestMark(
        marks: marks,
        layout: layout,
        viewport: vp,
        focalY: 5,
        canvasWidth: 360,
        focalX: 100,
      ),
      'allday',
    );
  });

  test('near edges returns null', () {
    final vp = makeVp();
    final marks = [
      StreamDayMark(
        id: 'm0',
        kind: StreamDayMarkKind.event,
        startMs: 0,
        endMs: 60 * 60 * 1000,
        title: 't',
        colorArgb: 0xFF000000,
      ),
    ];
    final layout = layoutMarkColumns([
      const MarkInterval(startMs: 0, endMs: 60 * 60 * 1000, id: 'm0'),
    ]);
    final y = vp.timeToPx(30 * 60 * 1000);
    expect(
      hitTestMark(
        marks: marks,
        layout: layout,
        viewport: vp,
        focalY: y,
        canvasWidth: 360,
        focalX: 2,
      ),
      isNull,
    );
    expect(
      hitTestMark(
        marks: marks,
        layout: layout,
        viewport: vp,
        focalY: y,
        canvasWidth: 360,
        focalX: 358,
      ),
      isNull,
    );
  });

  test('hit-test candidate checks bounded for 50k marks', () {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    final n = 50000;
    final marks = List.generate(n, (i) {
      final start = i * 60 * 1000; // 1 min apart
      return StreamDayMark(
        id: 'm$i',
        kind: StreamDayMarkKind.event,
        startMs: start,
        endMs: start + 30 * 60 * 1000,
        title: 't$i',
        colorArgb: 0xFF000000,
      );
    });
    final intervals = marks
        .map((m) => MarkInterval(startMs: m.startMs, endMs: m.endMs, id: m.id))
        .toList();
    final layout = layoutMarkColumns(intervals);
    resetHitTestCandidateChecks();
    final y = vp.timeToPx(60 * 60 * 1000); // 1h in
    final got = hitTestMark(
      marks: marks,
      layout: layout,
      viewport: vp,
      focalY: y,
      canvasWidth: 360,
      focalX: 100,
    );
    expect(got, isNotNull);
    // Candidate checks should be bounded, not O(n).
    expect(hitTestCandidateChecks, lessThan(100));
  });
}
