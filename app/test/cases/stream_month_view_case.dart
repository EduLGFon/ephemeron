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
}
