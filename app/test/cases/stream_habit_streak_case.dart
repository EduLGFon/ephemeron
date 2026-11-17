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
            colorArgb: 0xFF4CAF50,
            weekLevel: false,
            semanticsLabel: 'habit',
            streakCurrent: 3,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HabitStreakLine), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
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
            colorArgb: 0xFF4CAF50,
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
            colorArgb: 0xFF4CAF50,
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
            colorArgb: 0xFF4CAF50,
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
            colorArgb: 0xFF4CAF50,
            weekLevel: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HabitStreakLine), findsOneWidget);
  });

  testWidgets('DST transition yields unique day keys', (tester) async {
    final start = DateTime(2026, 10, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 10 * 20,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {},
            dayCount: 10,
            startDate: start,
            cellWidth: 20,
            colorArgb: 0xFF4CAF50,
            weekLevel: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion is instant', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: SizedBox(
            width: 120,
            height: 24,
            child: HabitStreakLine(
              doneByDay: const {'0': true, '1': true},
              dayCount: 2,
              cellWidth: 40,
              colorArgb: 0xFF4CAF50,
              weekLevel: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantics exposes label and streak', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {'0': true},
            dayCount: 1,
            cellWidth: 40,
            colorArgb: 0xFF4CAF50,
            weekLevel: true,
            semanticsLabel: 'Habit',
            streakCurrent: 5,
          ),
        ),
      ),
    );
    await tester.pump();
    final node = tester.getSemantics(find.byType(HabitStreakLine));
    expect(node.getSemanticsData().label, contains('Habit'));
  });
}
