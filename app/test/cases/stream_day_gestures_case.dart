import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/stream_mark_layout.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/gestures/day_mark_gestures.dart';
import 'package:ephemeron/features/stream/presentation/gestures/day_mark_gesture_layer.dart';
import 'package:ephemeron/features/stream/presentation/gestures/drag_mark_overlay.dart';
import 'package:ephemeron/features/stream/presentation/gestures/tray_drop_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppFeedback.hapticsEnabled = true;
  });

  StreamTimeViewport makeVp() {
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    return vp;
  }

  StreamDayMark eventMark(String id, int startMin, int endMin) => StreamDayMark(
    id: id,
    kind: StreamDayMarkKind.event,
    startMs: startMin * 60 * 1000,
    endMs: endMin * 60 * 1000,
    title: id,
    colorArgb: 0xFF000000,
  );

  Widget buildGestures({
    required StreamTimeViewport vp,
    required List<StreamDayMark> marks,
    void Function(String)? onSwipeDone,
    void Function(String)? onSwipePush,
    void Function(String, int)? onMoveMark,
    void Function(String, int)? onMoveMarkEnd,
    void Function(int, int)? onCreateBlock,
    void Function(String)? onMarkTap,
    int? snapMinutes = 15,
    ValueNotifier<DragPreviewData?>? dragPreview,
  }) {
    final intervals = marks
        .map((m) => MarkInterval(startMs: m.startMs, endMs: m.endMs, id: m.id))
        .toList();
    final layouts = intervals.isEmpty
        ? <MarkLayout>[]
        : layoutMarkColumns(intervals);
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 400,
          child: DayMarkGestures(
            viewport: vp,
            marks: marks,
            markLayouts: layouts,
            onSwipeDone: onSwipeDone,
            onSwipePush: onSwipePush,
            onMoveMark: onMoveMark,
            onMoveMarkEnd: onMoveMarkEnd,
            onCreateBlock: onCreateBlock,
            onMarkTap: onMarkTap,
            snapMinutes: snapMinutes,
            dragPreview: dragPreview,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  testWidgets('swipe right fires onSwipeDone once', (tester) async {
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
    var count = 0;
    String? got;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: marks,
        onSwipeDone: (id) {
          count++;
          got = id;
        },
      ),
    );
    await tester.pump();
    await tester.dragFrom(const Offset(100, 28), const Offset(80, 0));
    await tester.pump();
    expect(count, 1);
    expect(got, 'm0');
  });

  testWidgets('swipe left fires onSwipePush once', (tester) async {
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
    var count = 0;
    String? got;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: marks,
        onSwipePush: (id) {
          count++;
          got = id;
        },
      ),
    );
    await tester.pump();
    await tester.dragFrom(const Offset(100, 28), const Offset(-80, 0));
    await tester.pump();
    expect(count, 1);
    expect(got, 'm0');
  });

  testWidgets('swipe starting on empty space does nothing', (tester) async {
    final vp = makeVp();
    var done = 0;
    var push = 0;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: const [],
        onSwipeDone: (_) => done++,
        onSwipePush: (_) => push++,
      ),
    );
    await tester.pump();
    await tester.dragFrom(const Offset(100, 200), const Offset(80, 0));
    await tester.pump();
    await tester.dragFrom(const Offset(100, 200), const Offset(-80, 0));
    await tester.pump();
    expect(done, 0);
    expect(push, 0);
  });

  testWidgets('tap does nothing', (tester) async {
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
    var done = 0;
    var push = 0;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: marks,
        onSwipeDone: (_) => done++,
        onSwipePush: (_) => push++,
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(100, 28));
    await tester.pump();
    expect(done, 0);
    expect(push, 0);
  });

  testWidgets('tap on a mark fires onMarkTap once with its id', (tester) async {
    final vp = makeVp();
    final taps = <String>[];
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: [eventMark('m0', 0, 60)],
        onMarkTap: taps.add,
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(100, 28));
    await tester.pump();
    expect(taps, ['m0']);
  });

  testWidgets('tap on empty time fires no onMarkTap', (tester) async {
    final vp = makeVp();
    final taps = <String>[];
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: [eventMark('m0', 0, 60)],
        onMarkTap: taps.add,
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();
    expect(taps, isEmpty);
  });

  testWidgets('swipes fire swipe callbacks and not onMarkTap', (tester) async {
    final vp = makeVp();
    final taps = <String>[];
    final done = <String>[];
    final push = <String>[];
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: [eventMark('m0', 0, 60)],
        onMarkTap: taps.add,
        onSwipeDone: done.add,
        onSwipePush: push.add,
      ),
    );
    await tester.pump();
    await tester.dragFrom(const Offset(100, 28), const Offset(80, 0));
    await tester.pump();
    await tester.dragFrom(const Offset(100, 28), const Offset(-80, 0));
    await tester.pump();
    expect(done, ['m0']);
    expect(push, ['m0']);
    expect(taps, isEmpty);
  });

  testWidgets('long-press without movement fires no tap or move end', (
    tester,
  ) async {
    final vp = makeVp();
    final taps = <String>[];
    var moves = 0;
    var ends = 0;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: [eventMark('m0', 0, 60)],
        onMarkTap: taps.add,
        onMoveMark: (_, _) => moves++,
        onMoveMarkEnd: (_, _) => ends++,
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(100, 28));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    expect(taps, isEmpty);
    expect(moves, 0);
    expect(ends, 0);
  });

  testWidgets('long-press + move reports move and never a tap', (tester) async {
    final vp = makeVp();
    final taps = <String>[];
    final moves = <int>[];
    String? endedId;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: [eventMark('m0', 0, 60)],
        onMarkTap: taps.add,
        onMoveMark: (_, ms) => moves.add(ms),
        onMoveMarkEnd: (id, _) => endedId = id,
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(100, 28));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(moves, isNotEmpty);
    expect(endedId, 'm0');
    expect(taps, isEmpty);
  });

  testWidgets('tap on overlapping marks picks the painted column', (
    tester,
  ) async {
    final vp = makeVp();
    final taps = <String>[];
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: [eventMark('left', 0, 60), eventMark('right', 30, 90)],
        onMarkTap: taps.add,
      ),
    );
    await tester.pump();
    final y = vp.timeToPx(45 * 60 * 1000);
    await tester.tapAt(Offset(100, y));
    await tester.pump();
    await tester.tapAt(Offset(250, y));
    await tester.pump();
    expect(taps, ['left', 'right']);
  });

  testWidgets('taps inside the edge margin still fire onMarkTap', (
    tester,
  ) async {
    final vp = makeVp();
    final taps = <String>[];
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: [eventMark('m0', 0, 60)],
        onMarkTap: taps.add,
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(10, 28));
    await tester.pump();
    await tester.tapAt(const Offset(350, 28));
    await tester.pump();
    expect(taps, ['m0', 'm0']);
  });

  testWidgets('long-press + drag on mark reports move and snaps', (
    tester,
  ) async {
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
    final moves = <int>[];
    int? ended;
    String? endedId;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: marks,
        onMoveMark: (id, ms) {
          moves.add(ms);
        },
        onMoveMarkEnd: (id, ms) {
          endedId = id;
          ended = ms;
        },
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(100, 28));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(moves, isNotEmpty);
    for (final m in moves) {
      expect(m % (15 * 60 * 1000), 0);
    }
    expect(endedId, 'm0');
    expect(ended, isNotNull);
    expect(ended! % (15 * 60 * 1000), 0);
  });

  testWidgets('no-op long-press fires nothing', (tester) async {
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
    var moves = 0;
    var ends = 0;
    var creates = 0;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: marks,
        onMoveMark: (_, _) => moves++,
        onMoveMarkEnd: (_, _) => ends++,
        onCreateBlock: (_, _) => creates++,
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(100, 28));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    expect(moves, 0);
    expect(ends, 0);
    expect(creates, 0);
  });

  testWidgets('grab offset preserved on move', (tester) async {
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
    int? ended;
    await tester.pumpWidget(
      buildGestures(vp: vp, marks: marks, onMoveMarkEnd: (_, ms) => ended = ms),
    );
    await tester.pump();
    // press at 30 min into mark
    final pressY = vp.timeToPx(30 * 60 * 1000);
    final gesture = await tester.startGesture(Offset(100, pressY));
    await tester.pump(const Duration(milliseconds: 600));
    // drag down by ~30 min
    final deltaPx = vp.timeToPx(60 * 60 * 1000) - vp.timeToPx(30 * 60 * 1000);
    await gesture.moveBy(Offset(0, deltaPx));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(ended, isNotNull);
    // new start equals original start plus drag delta snapped, within 1 ms
    expect(ended!, closeTo(30 * 60 * 1000, 1));
  });

  testWidgets('long-press empty time creates block with exact times', (
    tester,
  ) async {
    final vp = makeVp();
    int? s;
    int? e;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: const [],
        onCreateBlock: (start, end) {
          s = start;
          e = end;
        },
      ),
    );
    await tester.pump();
    final startY = 200.0;
    final endY = 280.0;
    final gesture = await tester.startGesture(Offset(100, startY));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(Offset(0, endY - startY));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(s, vp.pxToTime(startY));
    expect(e, greaterThanOrEqualTo(s! + 15 * 60 * 1000));
  });

  testWidgets('edge 23.9 ignored, 24.1 allowed', (tester) async {
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
    var done = 0;
    await tester.pumpWidget(
      buildGestures(vp: vp, marks: marks, onSwipeDone: (_) => done++),
    );
    await tester.pump();
    await tester.dragFrom(const Offset(3.9, 28), const Offset(80, 0));
    await tester.pump();
    expect(done, 0);
    await tester.dragFrom(const Offset(4.1, 28), const Offset(80, 0));
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('tray chip drag reports onTrayDrop with exact time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vp = StreamTimeViewport(baseEpochMs: 0);
    vp.setViewportHeight(400);
    vp.setZoom(StreamTimeViewport.dayMinutesPerPixel);
    String? gotId;
    int? gotTime;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Draggable<String>(
                data: 'chip1',
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: const Text('chip'),
                child: const Text('chip'),
              ),
              Expanded(
                child: TrayDropTarget(
                  viewport: vp,
                  onTrayDrop: (id, t) {
                    gotId = id;
                    gotTime = t;
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final chipCenter = tester.getCenter(find.text('chip'));
    // drop at center of expanded target
    final targetRect = tester.getRect(find.byType(TrayDropTarget));
    final dropTarget = targetRect.center;
    await tester.dragFrom(chipCenter, dropTarget - chipCenter);
    await tester.pump();
    expect(gotId, 'chip1');
    final expectedTime = vp.pxToTime(targetRect.center.dy - targetRect.top);
    expect(gotTime, expectedTime);
  });

  testWidgets('tray drop inside margin ignored', (tester) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vp = makeVp();
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Draggable<String>(
                data: 'chip1',
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: const Text('chip'),
                child: const Text('chip'),
              ),
              Expanded(
                child: TrayDropTarget(
                  viewport: vp,
                  edgeMarginDp: 24,
                  onTrayDrop: (_, _) => called = true,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final chipCenter = tester.getCenter(find.text('chip'));
    final targetRect = tester.getRect(find.byType(TrayDropTarget));
    final drop = Offset(targetRect.left + 2, targetRect.center.dy);
    await tester.dragFrom(chipCenter, drop - chipCenter);
    await tester.pump();
    expect(called, isFalse);
  });

  testWidgets('tray drop at x=30 reports exact time', (tester) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vp = makeVp();
    String? gotId;
    int? gotTime;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Draggable<String>(
                data: 'chip1',
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: const Text('chip'),
                child: const Text('chip'),
              ),
              Expanded(
                child: TrayDropTarget(
                  viewport: vp,
                  edgeMarginDp: 24,
                  onTrayDrop: (id, t) {
                    gotId = id;
                    gotTime = t;
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final chipCenter = tester.getCenter(find.text('chip'));
    final targetRect = tester.getRect(find.byType(TrayDropTarget));
    final drop = Offset(targetRect.left + 30, targetRect.center.dy);
    await tester.dragFrom(chipCenter, drop - chipCenter);
    await tester.pump();
    expect(gotId, 'chip1');
    final expectedTime = vp.pxToTime(targetRect.center.dy - targetRect.top);
    expect(gotTime, expectedTime);
  });

  testWidgets('tray drop above and below bounds ignored', (tester) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vp = makeVp();
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Draggable<String>(
                data: 'chip1',
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: const Text('chip'),
                child: const Text('chip'),
              ),
              Expanded(
                child: TrayDropTarget(
                  viewport: vp,
                  edgeMarginDp: 24,
                  onTrayDrop: (_, _) => called = true,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final chipCenter = tester.getCenter(find.text('chip'));
    final targetRect = tester.getRect(find.byType(TrayDropTarget));
    final dropAbove = Offset(targetRect.left + 30, targetRect.top - 10);
    await tester.dragFrom(chipCenter, dropAbove - chipCenter);
    await tester.pump();
    expect(called, isFalse);
    final dropBelow = Offset(targetRect.left + 30, targetRect.bottom + 10);
    await tester.dragFrom(chipCenter, dropBelow - chipCenter);
    await tester.pump();
    expect(called, isFalse);
  });

  testWidgets('haptics disabled does not throw', (tester) async {
    AppFeedback.hapticsEnabled = false;
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
    await tester.pumpWidget(
      buildGestures(vp: vp, marks: marks, onSwipeDone: (_) {}),
    );
    await tester.pump();
    await tester.dragFrom(const Offset(100, 28), const Offset(80, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag preview notifier moves and clears', (tester) async {
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
    final notifier = ValueNotifier<DragPreviewData?>(null);
    await tester.pumpWidget(
      buildGestures(vp: vp, marks: marks, dragPreview: notifier),
    );
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(100, 28));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(notifier.value, isNotNull);
    await gesture.up();
    await tester.pump();
    expect(notifier.value, isNull);
  });
  testWidgets('overlay moves during drag and disappears on release', (
    tester,
  ) async {
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
    final intervals = marks
        .map((m) => MarkInterval(startMs: m.startMs, endMs: m.endMs, id: m.id))
        .toList();
    final layouts = layoutMarkColumns(intervals);
    final notifier = ValueNotifier<DragPreviewData?>(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: DayMarkGestureLayer(
              viewport: vp,
              marks: marks,
              markLayouts: layouts,
              dragPreview: notifier,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(100, 28));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(find.byType(DragMarkOverlay), findsOneWidget);
    final before = tester.widget<Positioned>(find.byType(Positioned)).top;
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    final after = tester.widget<Positioned>(find.byType(Positioned)).top;
    expect(after, isNot(equals(before)));
    await gesture.up();
    await tester.pump();
    expect(find.byType(DragMarkOverlay), findsNothing);
    expect(notifier.value, isNull);
  });
}
