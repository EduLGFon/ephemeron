import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/stream_mark_layout.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/gestures/day_mark_gestures.dart';
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

  Widget buildGestures({
    required StreamTimeViewport vp,
    required List<StreamDayMark> marks,
    required void Function(String) onSwipeDone,
    void Function(String)? onSwipePush,
    void Function(String, int)? onMoveMark,
    void Function(String, int)? onMoveMarkEnd,
    void Function(int, int)? onCreateBlock,
    void Function(String, VoidCallback)? onUndoRequested,
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
            onSwipePush: onSwipePush ?? (_) {},
            onMoveMark: onMoveMark,
            onMoveMarkEnd: onMoveMarkEnd,
            onCreateBlock: onCreateBlock,
            onUndoRequested: onUndoRequested,
            snapMinutes: 15,
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
        onSwipeDone: (_) {},
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
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: marks,
        onSwipeDone: (_) {},
        onMoveMark: (_, ms) => moves.add(ms),
        onMoveMarkEnd: (_, ms) => ended = ms,
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
    expect(ended, isNotNull);
    expect(ended! % (15 * 60 * 1000), 0);
  });

  testWidgets('long-press empty time creates block >= 15 min', (tester) async {
    final vp = makeVp();
    int? s;
    int? e;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: const [],
        onSwipeDone: (_) {},
        onCreateBlock: (start, end) {
          s = start;
          e = end;
        },
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(100, 200));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(s, isNotNull);
    expect(e, isNotNull);
    expect(e! - s!, greaterThanOrEqualTo(15 * 60 * 1000));
    expect(e! > s!, isTrue);
  });

  testWidgets('gesture starting near edge is ignored', (tester) async {
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
    await tester.dragFrom(const Offset(2, 200), const Offset(80, 0));
    await tester.pump();
    expect(done, 0);
    // right edge
    await tester.dragFrom(const Offset(358, 200), const Offset(-80, 0));
    await tester.pump();
    expect(done, 0);
  });

  testWidgets('tray chip drag reports onTrayDrop with time', (tester) async {
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
                feedback: const Text('chip'),
                child: const Text('chip'),
              ),
              SizedBox(
                width: 360,
                height: 300,
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
    final targetCenter =
        tester.getCenter(find.byType(SizedBox).last) + const Offset(0, 0);
    await tester.dragFrom(chipCenter, targetCenter - chipCenter);
    await tester.pump();
    expect(gotId, 'chip1');
    expect(gotTime, isNotNull);
  });

  testWidgets('undo calls onUndoRequested and callback works', (tester) async {
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
    VoidCallback? captured;
    var called = false;
    await tester.pumpWidget(
      buildGestures(
        vp: vp,
        marks: marks,
        onSwipeDone: (_) {},
        onUndoRequested: (desc, cb) {
          captured = cb;
        },
      ),
    );
    await tester.pump();
    await tester.dragFrom(const Offset(100, 28), const Offset(80, 0));
    await tester.pump();
    expect(captured, isNotNull);
    expect(() => captured!(), returnsNormally);
    captured!();
    called = true;
    expect(called, isTrue);
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
}
