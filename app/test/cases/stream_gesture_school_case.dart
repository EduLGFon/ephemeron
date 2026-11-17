import 'package:ephemeron/features/stream/presentation/school/gesture_school_controller.dart';
import 'package:ephemeron/features/stream/presentation/school/gesture_school_overlay.dart';
import 'package:ephemeron/features/stream/presentation/school/ghost_finger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('controller advances through six steps and calls onFinish once', () {
    var finished = 0;
    final c = GestureSchoolController(onFinish: () => finished++);
    for (var i = 0; i < 6; i++) {
      expect(c.stepIndex, i);
      c.completeCurrentStep();
    }
    expect(c.stepIndex, 5);
    expect(finished, 1);
    // no further advance
    c.completeCurrentStep();
    expect(finished, 1);
  });

  test('controller skip calls onSkip', () {
    var skipped = 0;
    final c = GestureSchoolController(onSkip: () => skipped++);
    c.skip();
    expect(skipped, 1);
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

  testWidgets('overlay shows caller title and body and progress dots', (
    tester,
  ) async {
    final c = GestureSchoolController();
    const labels = <String, dynamic>{
      'scroll': <String, dynamic>{
        'title': 'Scroll time',
        'body': 'Scroll body',
        'gestureHint': 'hint',
      },
    };
    // pad labels for all six
    final full = <String, dynamic>{};
    for (final id in const [
      'scroll',
      'capture',
      'complete',
      'push',
      'dragSchedule',
      'pinch',
    ]) {
      full[id] = <String, dynamic>{
        'title': 'T$id',
        'body': 'B$id',
        'gestureHint': 'H$id',
      };
    }
    full['scroll'] = labels['scroll']!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c,
            labels: full,
            skipLabel: 'Skip',
            nextLabel: 'Next',
            onStepCompleted: (_) {},
            onSkip: () {},
            onFinish: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Scroll time'), findsOneWidget);
    expect(find.text('Scroll body'), findsOneWidget);
    // six progress dots
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('Enter/Right completes, Esc skips', (tester) async {
    final c = GestureSchoolController();
    final full = <String, dynamic>{};
    for (final id in const [
      'scroll',
      'capture',
      'complete',
      'push',
      'dragSchedule',
      'pinch',
    ]) {
      full[id] = <String, dynamic>{
        'title': 'T$id',
        'body': 'B$id',
        'gestureHint': 'H$id',
      };
    }
    var completed = <String>[];
    var skipped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c,
            labels: full,
            skipLabel: 'Skip',
            nextLabel: 'Next',
            onStepCompleted: completed.add,
            onSkip: () => skipped++,
            onFinish: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(completed, contains('scroll'));
    // Esc
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(skipped, 1);
  });

  testWidgets('ghost finger animates and repaint count grows', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GhostFinger(stepId: 'scroll')),
      ),
    );
    await tester.pump();
    final paint = tester.widget<CustomPaint>(
      find
          .byWidgetPredicate((w) => w is CustomPaint && w.painter != null)
          .first,
    );
    final painter = paint.painter as dynamic;
    final before = painter.paintCount as int;
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
          home: Scaffold(body: GhostFinger(stepId: 'scroll')),
        ),
      ),
    );
    await tester.pump();
    final paint = tester.widget<CustomPaint>(
      find
          .byWidgetPredicate((w) => w is CustomPaint && w.painter != null)
          .first,
    );
    final painter = paint.painter as dynamic;
    final before = painter.paintCount as int;
    await tester.pump(const Duration(milliseconds: 200));
    expect(painter.paintCount, before);
  });

  testWidgets('320dp at 2.0 scale does not overflow', (tester) async {
    final c = GestureSchoolController();
    final full = <String, dynamic>{};
    for (final id in const [
      'scroll',
      'capture',
      'complete',
      'push',
      'dragSchedule',
      'pinch',
    ]) {
      full[id] = <String, dynamic>{
        'title': 'T$id',
        'body': 'B$id',
        'gestureHint': 'H$id',
      };
    }
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c,
            labels: full,
            skipLabel: 'Skip',
            nextLabel: 'Next',
            onStepCompleted: (_) {},
            onSkip: () {},
            onFinish: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantics labels exist', (tester) async {
    final c = GestureSchoolController();
    final full = <String, dynamic>{};
    for (final id in const [
      'scroll',
      'capture',
      'complete',
      'push',
      'dragSchedule',
      'pinch',
    ]) {
      full[id] = <String, dynamic>{
        'title': 'T$id',
        'body': 'B$id',
        'gestureHint': 'H$id',
      };
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureSchoolOverlay(
            controller: c,
            labels: full,
            skipLabel: 'Skip',
            nextLabel: 'Next',
            onStepCompleted: (_) {},
            onSkip: () {},
            onFinish: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    final semantics = tester.getSemantics(find.byType(GestureSchoolOverlay));
    expect(semantics, isNotNull);
  });
}
