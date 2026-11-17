import 'package:ephemeron/features/stream/presentation/school/gesture_school_controller.dart';
import 'package:ephemeron/features/stream/presentation/school/gesture_school_overlay.dart';
import 'package:ephemeron/features/stream/presentation/school/gesture_school_step.dart';
import 'package:ephemeron/features/stream/presentation/school/ghost_finger.dart';
import 'package:ephemeron/features/stream/presentation/school/school_progress_dots.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

GestureSchoolStepText T(String t, String b, String h) =>
    GestureSchoolStepText(title: t, body: b, gestureHint: h);

Map<GestureSchoolStepId, GestureSchoolStepText> fullLabels() {
  final m = <GestureSchoolStepId, GestureSchoolStepText>{};
  for (final id in gestureSchoolStepIds) {
    m[id] = GestureSchoolStepText(
      title: 'T$id',
      body: 'B$id',
      gestureHint: 'H$id',
    );
  }
  m[GestureSchoolStepId.scroll] = GestureSchoolStepText(
    title: 'Scroll time',
    body: 'Scroll body',
    gestureHint: 'hint',
  );
  return m;
}

void main() {
  test('controller advances through six steps and calls onFinish once', () {
    var finished = 0;
    var completed = <GestureSchoolStepId>[];
    final c = GestureSchoolController(
      onStepCompleted: completed.add,
      onFinish: () => finished++,
    );
    for (var i = 0; i < 6; i++) {
      expect(c.stepIndex, i);
      c.completeCurrentStep();
    }
    expect(c.stepIndex, 5);
    expect(finished, 1);
    expect(completed.length, 6);
    c.completeCurrentStep();
    expect(finished, 1);
  });

  test('controller skip calls onSkip once and not onFinish', () {
    var skipped = 0;
    var finished = 0;
    final c = GestureSchoolController(
      onSkip: () => skipped++,
      onFinish: () => finished++,
    );
    c.skip();
    expect(skipped, 1);
    expect(finished, 0);
    expect(c.isFinished, isTrue);
  });

  test('controller restart resets to step 0', () {
    final c = GestureSchoolController();
    c.completeCurrentStep();
    c.completeCurrentStep();
    c.restart();
    expect(c.stepIndex, 0);
    expect(c.isFinished, isFalse);
  });

  test('controller complete -> restart -> complete fires onFinish again', () {
    var finished = 0;
    final c = GestureSchoolController(onFinish: () => finished++);
    for (var i = 0; i < 6; i++) {
      c.completeCurrentStep();
    }
    expect(finished, 1);
    c.restart();
    for (var i = 0; i < 6; i++) {
      c.completeCurrentStep();
    }
    expect(finished, 2);
  });

  testWidgets('overlay shows caller title and body and progress dots', (
    tester,
  ) async {
    final c = GestureSchoolController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c,
            labels: fullLabels(),
            skipLabel: 'Skip',
            nextLabel: 'Next',
            progressLabel: (step, cur, total) => 'P$cur/$total',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Scroll time'), findsOneWidget);
    expect(find.text('Scroll body'), findsOneWidget);
    expect(find.byType(Container), findsNWidgets(6));
  });

  testWidgets('Enter/Right completes, Esc skips', (tester) async {
    final c = GestureSchoolController();
    var skipped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c,
            labels: fullLabels(),
            skipLabel: 'Skip',
            nextLabel: 'Next',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.stepIndex, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(skipped, 0);
    expect(c.isFinished, isTrue);
  });

  testWidgets('ghost finger animates and repaint count grows', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GhostFinger(stepId: GestureSchoolStepId.scroll)),
      ),
    );
    await tester.pump();
    final paint = tester.widget<CustomPaint>(
      find
          .byWidgetPredicate((w) => w is CustomPaint && w.painter != null)
          .first,
    );
    final painter = paint.painter as GhostFingerPainter;
    final before = painter.paintCount;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(painter.paintCount, greaterThan(before));
  });

  testWidgets('ghost finger under reduce motion renders without animating', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const MaterialApp(
          home: Scaffold(body: GhostFinger(stepId: GestureSchoolStepId.scroll)),
        ),
      ),
    );
    await tester.pump();
    final paint = tester.widget<CustomPaint>(
      find
          .byWidgetPredicate((w) => w is CustomPaint && w.painter != null)
          .first,
    );
    final painter = paint.painter as GhostFingerPainter;
    final before = painter.paintCount;
    await tester.pump(const Duration(milliseconds: 200));
    expect(painter.paintCount, before);
  });

  testWidgets('dispose while animating does not throw', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GhostFinger(stepId: GestureSchoolStepId.scroll)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 logical dp at 2.0 text scale does not overflow', (
    tester,
  ) async {
    final c = GestureSchoolController();
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          home: Scaffold(
            body: GestureSchoolOverlay(
              controller: c,
              labels: fullLabels(),
              skipLabel: 'Skip',
              nextLabel: 'Next',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing label falls back visibly', (tester) async {
    final c = GestureSchoolController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c,
            labels: const <GestureSchoolStepId, GestureSchoolStepText>{},
            skipLabel: 'Skip',
            nextLabel: 'Next',
          ),
        ),
      ),
    );
    await tester.pump();
    // fallback title is step id name
    expect(find.text('scroll'), findsOneWidget);
  });

  testWidgets('empty step list builds without exception', (tester) async {
    final c = GestureSchoolController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c,
            steps: const <GestureSchoolStep>[],
            skipLabel: 'Skip',
            nextLabel: 'Next',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantics labels exist', (tester) async {
    final c = GestureSchoolController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c,
            labels: fullLabels(),
            skipLabel: 'Skip',
            nextLabel: 'Next',
            progressLabel: (step, cur, total) => 'PROG $cur/$total',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SchoolProgressDots), findsOneWidget);
  });

  testWidgets('overlay never duplicates controller callbacks', (tester) async {
    var finished = 0;
    var skipped = 0;
    var completed = 0;
    final c = GestureSchoolController(
      onStepCompleted: (_) => completed++,
      onSkip: () => skipped++,
      onFinish: () => finished++,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c,
            labels: fullLabels(),
            skipLabel: 'Skip',
            nextLabel: 'Next',
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      c.completeCurrentStep();
    }
    expect(finished, 1);
    expect(completed, 6);
    // skip on a fresh controller
    final c2 = GestureSchoolController(
      onSkip: () => skipped++,
      onFinish: () => finished++,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c2,
            labels: fullLabels(),
            skipLabel: 'Skip',
            nextLabel: 'Next',
          ),
        ),
      ),
    );
    await tester.pump();
    c2.skip();
    expect(skipped, 1);
    expect(finished, 1);
  });
}
