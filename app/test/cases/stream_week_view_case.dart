import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/presentation/levels/week_view.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders seven days', (tester) async {
    final marks = <StreamDayMark>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 200,
            child: WeekView(
              weekStart: DateTime(2026, 1, 5),
              marks: marks,
              cellWidth: 40,
              cellHeight: 200,
              dayHeaderBuilder: (i, d) => 'D$i',
              daySemanticsLabel: (i, [d]) => 'day $i',
              markSemanticsLabel: (m) => m.title,
              markActionLabels: const {
                'complete': 'complete',
                'push': 'push',
                'reschedule': 'reschedule',
                'delete': 'delete',
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('culles 5000-mark year to visible week', (tester) async {
    final start = DateTime(2026, 1, 1);
    final marks = List.generate(5000, (i) {
      final ms = start.millisecondsSinceEpoch + i * 3600 * 1000;
      return StreamDayMark(
        id: 'm$i',
        kind: StreamDayMarkKind.event,
        startMs: ms,
        endMs: ms + 30 * 60 * 1000,
        title: 't$i',
        colorArgb: 0xFF000000,
      );
    });
    int? culled;
    final weekStart = DateTime(2026, 6, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 200,
            child: WeekView(
              weekStart: weekStart,
              marks: marks,
              cellWidth: 40,
              cellHeight: 200,
              dayHeaderBuilder: (i, d) => 'D$i',
              daySemanticsLabel: (i, [d]) => 'day $i',
              markSemanticsLabel: (m) => m.title,
              markActionLabels: const {
                'complete': 'complete',
                'push': 'push',
                'reschedule': 'reschedule',
                'delete': 'delete',
              },
              onCulledCount: (c) => culled = c,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(culled, isNotNull);
    expect(culled!, 4832);
  });

  testWidgets('max three chips plus overflow label', (tester) async {
    final ws = DateTime(2026, 1, 5);
    final dayMs = ws.millisecondsSinceEpoch;
    final marks = List.generate(5, (i) {
      final ms = dayMs + i * 60 * 60 * 1000;
      return StreamDayMark(
        id: 'm$i',
        kind: StreamDayMarkKind.event,
        startMs: ms,
        endMs: ms + 30 * 60 * 1000,
        title: 't$i',
        colorArgb: 0xFF000000,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 200,
            child: WeekView(
              weekStart: ws,
              marks: marks,
              cellWidth: 40,
              cellHeight: 200,
              dayHeaderBuilder: (i, d) => 'D$i',
              daySemanticsLabel: (i, [d]) => 'day $i',
              markSemanticsLabel: (m) => m.title,
              markActionLabels: const {
                'complete': 'complete',
                'push': 'push',
                'reschedule': 'reschedule',
                'delete': 'delete',
              },
              maxChips: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap maps to mark id and day', (tester) async {
    final ws = DateTime(2026, 1, 5);
    final ms = ws.millisecondsSinceEpoch;
    final mark = StreamDayMark(
      id: 'mark-1',
      kind: StreamDayMarkKind.event,
      startMs: ms,
      endMs: ms + 30 * 60 * 1000,
      title: 't',
      colorArgb: 0xFF000000,
    );
    String? tappedMark;
    DateTime? tappedDay;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 200,
            child: WeekView(
              weekStart: ws,
              marks: [mark],
              cellWidth: 40,
              cellHeight: 200,
              dayHeaderBuilder: (i, d) => 'D$i',
              daySemanticsLabel: (i, [d]) => 'day $i',
              markSemanticsLabel: (m) => m.title,
              markActionLabels: const {
                'complete': 'complete',
                'push': 'push',
                'reschedule': 'reschedule',
                'delete': 'delete',
              },
              onMarkTap: (id) => tappedMark = id,
              onDayTap: (d) => tappedDay = d,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // tap chip in first day
    await tester.tapAt(const Offset(20, 31));
    await tester.pump();
    expect(tappedMark, 'mark-1');

    // tap empty column day 2
    await tester.tapAt(const Offset(60, 190));
    await tester.pump();
    expect(tappedDay, ws.add(const Duration(days: 1)));
  });

  testWidgets('semantics nodes per day and mark with custom actions', (
    tester,
  ) async {
    final ws = DateTime(2026, 1, 5);
    final ms = ws.millisecondsSinceEpoch;
    final mark = StreamDayMark(
      id: 'mark-1',
      kind: StreamDayMarkKind.event,
      startMs: ms,
      endMs: ms + 30 * 60 * 1000,
      title: 'alpha',
      colorArgb: 0xFF000000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 200,
            child: WeekView(
              weekStart: ws,
              marks: [mark],
              cellWidth: 40,
              cellHeight: 200,
              dayHeaderBuilder: (i, d) => 'D$i',
              daySemanticsLabel: (i, [d]) => 'day $i',
              markSemanticsLabel: (m) => m.title,
              markActionLabels: const {
                'complete': 'complete',
                'push': 'push',
                'reschedule': 'reschedule',
                'delete': 'delete',
              },
              onCompleteMark: (_) {},
              onPushMark: (_) {},
              onRescheduleMark: (_) {},
              onDeleteMark: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final root = tester.getSemantics(find.byType(MaterialApp));
    final labels = <String>[];
    void collect(SemanticsNode n) {
      if (n.label.isNotEmpty) labels.add(n.label);
      n.visitChildren((c) {
        collect(c);
        return true;
      });
    }

    collect(root);
    expect(
      labels.where((l) => l.contains('alpha')).length,
      greaterThanOrEqualTo(1),
    );
    // custom actions count
    SemanticsNode? markNode;
    void findNode(SemanticsNode n) {
      if (n.label.contains('alpha')) markNode = n;
      n.visitChildren((c) {
        findNode(c);
        return true;
      });
    }

    findNode(root);
    expect(markNode, isNotNull);
    final data = markNode!.getSemanticsData();
    expect(data.customSemanticsActionIds, isNotNull);
    expect(data.customSemanticsActionIds!.length, 4);
  });

  testWidgets('320dp at 2.0 scale no overflow', (tester) async {
    final ws = DateTime(2026, 1, 5);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 200,
            child: WeekView(
              weekStart: ws,
              marks: const [],
              cellWidth: 45,
              cellHeight: 200,
              dayHeaderBuilder: (i, d) => 'D$i',
              daySemanticsLabel: (i, [d]) => 'day $i',
              markSemanticsLabel: (m) => m.title,
              markActionLabels: const {
                'complete': 'complete',
                'push': 'push',
                'reschedule': 'reschedule',
                'delete': 'delete',
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
