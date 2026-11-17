import 'package:ephemeron/features/stream/presentation/habits/habit_streak_line.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('consecutive days draw a line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {'0': true, '1': true, '2': true},
            dayCount: 3,
            cellWidth: 40,
            weekLevel: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HabitStreakLine), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a gap breaks it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {'0': true, '1': false, '2': true},
            dayCount: 3,
            cellWidth: 40,
            weekLevel: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single day draws a dot', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 40,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {'0': true},
            dayCount: 1,
            cellWidth: 40,
            weekLevel: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HabitStreakLine), findsOneWidget);
  });

  testWidgets('a Month range with 31 days is deterministic', (tester) async {
    final done = <String, bool>{};
    for (var i = 0; i < 31; i++) {
      done['$i'] = i % 2 == 0;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 31 * 10,
          height: 24,
          child: HabitStreakLine(
            doneByDay: done,
            dayCount: 31,
            cellWidth: 10,
            weekLevel: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero days draws nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 0,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {},
            dayCount: 0,
            cellWidth: 40,
            weekLevel: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HabitStreakLine), findsOneWidget);
  });
}
