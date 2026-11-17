import 'package:ephemeron/features/stream/presentation/focus/focus_band.dart';
import 'package:ephemeron/features/stream/presentation/focus/focus_clock.dart';
import 'package:ephemeron/features/stream/presentation/focus/focus_dim.dart';
import 'package:ephemeron/features/stream/presentation/focus/focus_timer_controls.dart';
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
}
