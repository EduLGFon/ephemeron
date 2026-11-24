import 'package:ephemeron/features/stream/engine/time_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scroll offset moves drawn content', () {
    final vp = TimeViewport(
      minMsPerPixel: 1000,
      maxMsPerPixel: 100000,
      baseEpochMs: 0,
    );
    vp.setViewportHeight(400);
    vp.setZoom(60000); // 1 minute per pixel
    const n = 10.0;
    // Time that sits at pixel N before scrolling.
    final timeAtN = vp.pxToTime(n);
    vp.setOffset(n);
    // After offset, that time maps to pixel 0.
    expect(vp.timeToPx(timeAtN), closeTo(0.0, 1e-6));
    // pxToTime(0) moves forward by N * msPerPixel.
    expect(vp.pxToTime(0), closeTo((n * vp.msPerPixel).round(), 1));
  });
}
