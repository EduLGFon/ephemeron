import 'package:ephemeron/features/stream/presentation/focus/focus_band.dart';
import 'package:ephemeron/features/stream/presentation/focus/focus_clock.dart';
import 'package:ephemeron/features/stream/presentation/focus/focus_dim.dart';
import 'package:ephemeron/features/stream/presentation/focus/focus_timer_controls.dart';

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('FocusClock', () {
    testWidgets('advances with injected now', (tester) async {
      var t = DateTime(2026, 1, 1);
      final clock = FocusClock(now: () => t);
      clock.start();
      t = t.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(clock.elapsed.value, const Duration(seconds: 3));
      clock.dispose();
    });

    testWidgets('pause freezes elapsed', (tester) async {
      var t = DateTime(2026, 1, 1);
      final clock = FocusClock(now: () => t);
      clock.start();
      t = t.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      clock.pause();
      t = t.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(clock.elapsed.value, const Duration(seconds: 2));
      clock.dispose();
    });

    testWidgets('resume continues', (tester) async {
      var t = DateTime(2026, 1, 1);
      final clock = FocusClock(now: () => t);
      clock.start();
      t = t.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      clock.pause();
      t = t.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      clock.resume();
      t = t.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(clock.elapsed.value, const Duration(seconds: 5));
      clock.dispose();
    });

    testWidgets('stop keeps final elapsed', (tester) async {
      var t = DateTime(2026, 1, 1);
      final clock = FocusClock(now: () => t);
      clock.start();
      t = t.add(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      clock.stop();
      t = t.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(clock.elapsed.value, const Duration(seconds: 4));
      clock.dispose();
    });
  });

  test('focusDimTier pure mapping', () {
    expect(
      focusDimTier(focusActive: false, isFocusedMark: false),
      FocusDimTier.none,
    );
    expect(
      focusDimTier(focusActive: true, isFocusedMark: true),
      FocusDimTier.none,
    );
    expect(
      focusDimTier(focusActive: true, isFocusedMark: false),
      FocusDimTier.dim,
    );
    expect(
      focusDimTier(focusActive: true, isFocusedMark: false, distanceSteps: 3),
      FocusDimTier.dimmer,
    );
  });

  test('band painter progress active/completed', () {
    final active = FocusBandPainter(
      mode: FocusBandMode.active,
      progress: 0.4,
      color: Colors.red,
    );
    expect(active.progress, 0.4);
    expect(active.mode, FocusBandMode.active);

    final completed = FocusBandPainter(
      mode: FocusBandMode.completed,
      segmentStart: 0.2,
      segmentEnd: 0.35,
      color: Colors.red,
    );
    expect(completed.segmentStart, 0.2);
    expect(completed.segmentEnd, 0.35);
    expect(completed.mode, FocusBandMode.completed);
  });

  testWidgets('timer digits update without parent rebuild', (tester) async {
    var t = DateTime(2026, 1, 1);
    final clock = FocusClock(now: () => t);
    clock.start();
    var parentBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              parentBuilds++;
              return FocusTimerControls(
                clock: clock,
                pauseLabel: 'Pause',
                resumeLabel: 'Resume',
                stopLabel: 'Stop',
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final before = parentBuilds;
    t = t.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(parentBuilds, before);
    clock.dispose();
  });

  testWidgets('pause and stop callbacks fire', (tester) async {
    var t = DateTime(2026, 1, 1);
    final clock = FocusClock(now: () => t);
    clock.start();
    var paused = false;
    var stopped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusTimerControls(
            clock: clock,
            pauseLabel: 'Pause',
            resumeLabel: 'Resume',
            stopLabel: 'Stop',
            onPause: () => paused = true,
            onStop: () => stopped = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(paused, isTrue);
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();
    expect(stopped, isTrue);
    clock.dispose();
  });

  testWidgets('semantics labels exist', (tester) async {
    var t = DateTime(2026, 1, 1);
    final clock = FocusClock(now: () => t);
    clock.start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusTimerControls(
            clock: clock,
            pauseLabel: 'Pause',
            resumeLabel: 'Resume',
            stopLabel: 'Stop',
            pauseSemanticsLabel: 'pause-timer',
            stopSemanticsLabel: 'stop-timer',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('pause-timer'), findsOneWidget);
    expect(find.bySemanticsLabel('stop-timer'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusBand(
            mode: FocusBandMode.active,
            progress: 0.5,
            color: Colors.red,
            semanticsLabel: 'focus-band',
            elapsedText: '00:05',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('focus-band'), findsOneWidget);
    clock.dispose();
  });

  testWidgets('reduce motion does not break rendering', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: FocusBand(
              mode: FocusBandMode.active,
              progress: 0.5,
              color: Colors.red,
              semanticsLabel: 'band',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(FocusBand), findsOneWidget);
  });

  testWidgets('320dp at 2.0 scale no overflow (timer)', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var t = DateTime(2026, 1, 1);
    final clock = FocusClock(now: () => t);
    clock.start();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: FocusTimerControls(
                clock: clock,
                pauseLabel: 'Pause',
                resumeLabel: 'Resume',
                stopLabel: 'Stop',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    clock.dispose();
  });

  testWidgets('clock pause at zero', (tester) async {
    var t = DateTime(2026, 1, 1);
    final clock = FocusClock(now: () => t);
    clock.start();
    clock.pause();
    expect(clock.elapsed.value, Duration.zero);
    clock.dispose();
  });

  testWidgets('clock stop idempotent', (tester) async {
    var t = DateTime(2026, 1, 1);
    final clock = FocusClock(now: () => t);
    clock.start();
    t = t.add(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
    clock.stop();
    final first = clock.elapsed.value;
    clock.stop();
    expect(clock.elapsed.value, first);
    clock.dispose();
  });

  testWidgets('clock tick after dispose no exception', (tester) async {
    var t = DateTime(2026, 1, 1);
    final clock = FocusClock(now: () => t);
    clock.start();
    clock.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(true, isTrue);
  });

  testWidgets('clock session over 24h', (tester) async {
    var t = DateTime(2026, 1, 1);
    final clock = FocusClock(now: () => t);
    clock.start();
    t = t.add(const Duration(hours: 25));
    await tester.pump(const Duration(seconds: 1));
    // advance timer by pumping full? Use direct tick via elapsed not enough; pump remaining
    await tester.pump(const Duration(hours: 25));
    expect(clock.elapsed.value.inHours, 25);
    clock.dispose();
  });

  test('band painter safe geometry', () {
    for (final h in [0.0, 2.0, 100.0]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = FocusBandPainter(
        mode: FocusBandMode.completed,
        segmentStart: 0.1,
        segmentEnd: 0.9,
        color: Colors.red,
        thickness: 3,
      );
      painter.paint(canvas, Size(10, h));
      recorder.endRecording();
    }
    expect(true, isTrue);
  });

  testWidgets('band repaint listenable triggers repaint', (tester) async {
    final notifier = ValueNotifier<int>(0);
    var paints = 0;
    final painter = _CountingBandPainter(
      mode: FocusBandMode.active,
      progress: 0.5,
      color: Colors.red,
      repaintListenable: notifier,
      onPaint: () => paints++,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 10,
            height: 100,
            child: CustomPaint(painter: painter),
          ),
        ),
      ),
    );
    await tester.pump();
    final before = paints;
    notifier.value = 1;
    await tester.pump();
    expect(paints, greaterThan(before));
  });

  testWidgets('pause resumes exactly once', (tester) async {
    var t = DateTime(2026, 1, 1);
    final clock = FocusClock(now: () => t);
    clock.start();
    var resumeCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusTimerControls(
            clock: clock,
            pauseLabel: 'Pause',
            resumeLabel: 'Resume',
            stopLabel: 'Stop',
            onPause: () => clock.pause(),
            onResume: () {
              resumeCalls++;
              clock.resume();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(resumeCalls, 1);
    clock.dispose();
  });

  testWidgets('320dp 2.0 scale no overflow timer', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var t = DateTime(2026, 1, 1);
    final clock = FocusClock(now: () => t);
    clock.start();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: FocusTimerControls(
                clock: clock,
                pauseLabel: 'Pause',
                resumeLabel: 'Resume',
                stopLabel: 'Stop',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byType(Text).first);
    expect(rect.right, lessThanOrEqualTo(320));
    clock.dispose();
  });
}

class _CountingBandPainter extends FocusBandPainter {
  _CountingBandPainter({
    required super.mode,
    required super.progress,
    required super.color,
    required super.repaintListenable,
    required this.onPaint,
  });

  final void Function() onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    super.paint(canvas, size);
  }
}
