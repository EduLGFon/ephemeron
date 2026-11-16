import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversions include offset', () {
    final vp = StreamTimeViewport(baseEpochMs: 1000);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    vp.setOffset(10);
    final t = vp.pxToTime(5);
    expect(vp.timeToPx(t), closeTo(5.0, 1e-3));
  });

  test('zoom anchor keeps focal time stable', () {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    vp.setOffset(0);
    final focal = 120.0;
    final timeBefore = vp.pxToTime(focal);
    vp.setZoom(StreamTimeViewport.hourMinutesPerPixel, focalPx: focal);
    final timeAfter = vp.pxToTime(focal);
    expect(timeAfter, timeBefore);
  });

  test('clamping', () {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setOffset(-1000);
    expect(vp.offsetPx, 0.0);
    vp.setZoom(1000); // out of range -> clamped to day
    expect(vp.minutesPerPixel, StreamTimeViewport.dayMinutesPerPixel);
  });

  test('preset scales produce exact dp per hour', () {
    expect(StreamTimeViewport.hourMinutesPerPixel, closeTo(60.0 / 160.0, 1e-9));
    expect(StreamTimeViewport.dayMinutesPerPixel, closeTo(60.0 / 56.0, 1e-9));
    final vp = StreamTimeViewport(
      baseEpochMs: 0,
      initialPreset: StreamZoomPreset.hour,
    );
    expect(vp.minutesPerPixel, closeTo(60.0 / 160.0, 1e-9));
  });
}
