import 'dart:developer' as dev;

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/features/stream/presentation/stream_spike_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('stream spike scroll + pinch', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StreamSpikeScreen()));
    await tester.pumpAndSettle();

    final timings = <FrameTiming>[];
    SchedulerBinding.instance.addTimingsCallback(timings.addAll);

    // Scroll.
    for (var i = 0; i < 200; i++) {
      await tester.drag(find.byType(StreamSpikeScreen), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Pinch zoom.
    final center = tester.getCenter(find.byType(StreamSpikeScreen));
    final gesture1 = await tester.startGesture(center + const Offset(-50, 0));
    final gesture2 = await tester.startGesture(center + const Offset(50, 0));
    for (var i = 0; i < 60; i++) {
      await gesture1.moveBy(const Offset(-2, 0));
      await gesture2.moveBy(const Offset(2, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture1.up();
    await gesture2.up();
    await tester.pumpAndSettle();

    SchedulerBinding.instance.removeTimingsCallback(timings.addAll);

    final builds = timings
        .map((t) => t.buildDuration.inMicroseconds / 1000.0)
        .toList();
    final rasters = timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000.0)
        .toList();
    builds.sort();
    rasters.sort();
    double pct(List<double> v, double p) =>
        v[(v.length * p).floor().clamp(0, v.length - 1)];
    final janky = timings
        .where(
          (t) =>
              t.buildDuration.inMilliseconds + t.rasterDuration.inMilliseconds >
              16,
        )
        .length;
    dev.log('FRAMES=${timings.length}');
    dev.log(
      'BUILD avg=${(builds.reduce((a, b) => a + b) / builds.length).toStringAsFixed(2)} p90=${pct(builds, 0.9).toStringAsFixed(2)} p99=${pct(builds, 0.99).toStringAsFixed(2)}',
    );
    dev.log(
      'RASTER avg=${(rasters.reduce((a, b) => a + b) / rasters.length).toStringAsFixed(2)} p90=${pct(rasters, 0.9).toStringAsFixed(2)} p99=${pct(rasters, 0.99).toStringAsFixed(2)}',
    );
    dev.log('JANKY=${(janky / timings.length * 100).toStringAsFixed(2)}%');

    await binding.traceAction(() async {
      await tester.drag(find.byType(StreamSpikeScreen), const Offset(0, -500));
      await tester.pumpAndSettle();
    }, reportKey: 'scroll');
  });
}
