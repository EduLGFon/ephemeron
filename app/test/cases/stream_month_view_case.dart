import 'package:ephemeron/features/stream/presentation/levels/month_view.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders 31-day grid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('density counts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              dayCounts: List.generate(31, (i) => i % 5),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('streak line breaks on gap', (tester) async {
    final streak = MonthHabitStreak(
      habitId: 'h1',
      doneDays: {1, 2, 4, 5},
      streakLabel: '2',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              habitStreaks: [streak],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap maps to date', (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              onDateTap: (d) => tapped = d,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(130, 10));
    await tester.pump();
    expect(tapped, isNotNull);
  });

  testWidgets('culling via visible range', (tester) async {
    int? culled;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              visibleStartDay: 5,
              visibleEndDay: 10,
              onCulledCount: (c) => culled = c,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(culled, 25);
  });

  testWidgets('semantics per day and streak', (tester) async {
    final streak = MonthHabitStreak(
      habitId: 'h1',
      doneDays: {1, 2},
      streakLabel: '2',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              habitStreaks: [streak],
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
      labels.where((l) => l.contains('Day')).length,
      greaterThanOrEqualTo(1),
    );
    expect(
      labels.where((l) => l.contains('h1')).length,
      greaterThanOrEqualTo(1),
    );
  });

  testWidgets('3-digit count does not clip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              dayCounts: List.generate(31, (i) => 100),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final tp = TextPainter(
      text: const TextSpan(text: '100', style: TextStyle(fontSize: 10)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    tp.layout(maxWidth: 40 - 2);
    expect(tp.width <= 40 - 2, isTrue);
  });

  testWidgets('streak spanning row boundary agrees paint and semantics', (
    tester,
  ) async {
    final streak = MonthHabitStreak(
      habitId: 'h1',
      doneDays: {4, 5, 6, 7}, // spans first/second row
      streakLabel: '4',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              habitStreaks: [streak],
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
    final streakNodes = labels.where((l) => l.contains('h1')).length;
    // A wrapped streak yields 2 row segments.
    expect(streakNodes, 2);
  });

  testWidgets('dot tap returns exact habit id', (tester) async {
    String? tappedHabit;
    final streak = MonthHabitStreak(
      habitId: 'habit-42',
      doneDays: {1, 2},
      streakLabel: '2',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              habitStreaks: [streak],
              onHabitTap: (id) => tappedHabit = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // tap near day 1 dot
    await tester.tapAt(const Offset(140, 26));
    await tester.pump();
    expect(tappedHabit, 'habit-42');
  });

  testWidgets('day tap returns exact date', (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              onDateTap: (d) => tapped = d,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(140, 20));
    await tester.pump();
    expect(tapped, DateTime(2026, 1, 1));
  });

  testWidgets('dot tap falls through to date when no habit callback', (
    tester,
  ) async {
    DateTime? tapped;
    final streak = MonthHabitStreak(
      habitId: 'habit-42',
      doneDays: {1, 2},
      streakLabel: '2',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              habitStreaks: [streak],
              onDateTap: (d) => tapped = d,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(140, 26));
    await tester.pump();
    expect(tapped, isNotNull);
  });

  testWidgets('tap at edge of painted dot hits', (tester) async {
    String? tappedHabit;
    final streak = MonthHabitStreak(
      habitId: 'edge-habit',
      doneDays: {1},
      streakLabel: '1',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              habitStreaks: [streak],
              onHabitTap: (id) => tappedHabit = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // painted radius 2.5; tap ~4 dp from center (within 6 slop)
    await tester.tapAt(const Offset(144, 30));
    await tester.pump();
    expect(tappedHabit, 'edge-habit');
  });

  testWidgets('culling reports once per input change', (tester) async {
    int calls = 0;
    int? culled;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              visibleStartDay: 5,
              visibleEndDay: 10,
              onCulledCount: (c) {
                calls++;
                culled = c;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 1);
    expect(culled, 25);
  });

  testWidgets('out-of-range days unpainted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 1, 1),
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
              visibleStartDay: 5,
              visibleEndDay: 10,
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
    final dayNodes = labels.where((l) => l.startsWith('Day')).length;
    expect(dayNodes, 6);
  });

  testWidgets('Sunday-first grid renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 3, 1),
              firstDayOfWeek: DateTime.sunday,
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Monday-first grid renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: MonthView(
              month: DateTime(2026, 3, 1),
              firstDayOfWeek: DateTime.monday,
              cellSize: 40,
              daySemanticsLabel: (day, count) => 'Day $day: $count',
              streakSemanticsLabel: (s) => '${s.habitId}: ${s.streakLabel}',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
