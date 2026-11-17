import 'package:ephemeron/features/stream/presentation/habits/habit_streak_line.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('pure layout: consecutive days produce segments', () {
    final layout = computeHabitStreakLayout(
      done: const [true, true, true],
      showDots: false,
      progress: 1,
    );
    expect(layout.segments, 2);
  });

  test('pure layout: gap breaks segments', () {
    final layout = computeHabitStreakLayout(
      done: const [true, false, true],
      showDots: false,
      progress: 1,
    );
    expect(layout.segments, 0);
  });

  test('pure layout: zero days produce nothing', () {
    final layout = computeHabitStreakLayout(
      done: const [],
      showDots: false,
      progress: 1,
    );
    expect(layout.segments, 0);
    expect(layout.dots, 0);
  });

  test('pure layout: single day draws a dot', () {
    final layout = computeHabitStreakLayout(
      done: const [true],
      showDots: true,
      progress: 1,
    );
    expect(layout.dots, 1);
    expect(layout.filledDots, 1);
  });

  test('pure keys: DST transition unique', () {
    final keys = habitStreakDayKeys(
      dayCount: 10,
      startDate: DateTime(2026, 10, 30),
    );
    expect(keys.length, 10);
    expect(keys.toSet().length, 10);
  });

  testWidgets('consecutive days draw a line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {'0': true, '1': true, '2': true},
            dayKeys: const ['0', '1', '2'],
            cellWidth: 40,
            colorArgb: 0xFF4CAF50,
            weekLevel: false,
            semanticsLabel: 'Habit',
            streakCurrent: 3,
            streakLabel: (v) => 'Streak $v',
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
            dayKeys: const ['0', '1', '2'],
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
            dayKeys: const ['0'],
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
      final d = DateTime(2026, 1, 1 + i);
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      done[key] = i % 2 == 0;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 31 * 10,
          height: 24,
          child: HabitStreakLine(
            doneByDay: done,
            dayCount: 31,
            startDate: DateTime(2026, 1, 1),
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
    final done = <String, bool>{};
    for (var i = 0; i < 10; i++) {
      final d = DateTime(2026, 10, 30 + i);
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      done[key] = i.isEven;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 10 * 20,
          height: 24,
          child: HabitStreakLine(
            doneByDay: done,
            dayCount: 10,
            startDate: DateTime(2026, 10, 30),
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
              dayKeys: const ['0', '1'],
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
            dayKeys: const ['0'],
            cellWidth: 40,
            colorArgb: 0xFF4CAF50,
            weekLevel: true,
            semanticsLabel: 'Habit',
            streakCurrent: 5,
            streakLabel: (v) => 'Streak $v',
          ),
        ),
      ),
    );
    await tester.pump();
    final node = tester.getSemantics(find.byType(HabitStreakLine));
    expect(node.getSemanticsData().label, contains('Habit'));
    expect(node.getSemanticsData().label, contains('5'));
  });

  testWidgets('painted: consecutive days draw two line segments', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {'0': true, '1': true, '2': true},
            dayKeys: const ['0', '1', '2'],
            cellWidth: 40,
            colorArgb: 0xFF4CAF50,
            weekLevel: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final cp = find.descendant(
      of: find.byType(HabitStreakLine),
      matching: find.byType(CustomPaint),
    );
    expect(
      cp,
      paints
        ..line(p1: const Offset(20, 300), p2: const Offset(60, 300))
        ..line(p1: const Offset(60, 300), p2: const Offset(100, 300)),
    );
    expect(cp, paintsExactlyCountTimes(#drawLine, 2));
  });

  testWidgets('painted: a gap yields two separate segments', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {
              '0': true,
              '1': true,
              '2': false,
              '3': true,
              '4': true,
            },
            dayKeys: const ['0', '1', '2', '3', '4'],
            cellWidth: 40,
            colorArgb: 0xFF4CAF50,
            weekLevel: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final cp = find.descendant(
      of: find.byType(HabitStreakLine),
      matching: find.byType(CustomPaint),
    );
    expect(
      cp,
      paints
        ..line(p1: const Offset(20, 300), p2: const Offset(60, 300))
        ..line(p1: const Offset(140, 300), p2: const Offset(180, 300)),
    );
    expect(cp, paintsExactlyCountTimes(#drawLine, 2));
  });

  testWidgets('painted: a single day draws a dot and no line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 40,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {'0': true},
            dayKeys: const ['0'],
            cellWidth: 40,
            colorArgb: 0xFF4CAF50,
            weekLevel: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final cp = find.descendant(
      of: find.byType(HabitStreakLine),
      matching: find.byType(CustomPaint),
    );
    expect(cp, paints..circle(x: 20, y: 300, radius: 3));
    expect(cp, paintsExactlyCountTimes(#drawLine, 0));
  });

  testWidgets('painted: zero done days draws nothing', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 200));
    final cp = find.descendant(
      of: find.byType(HabitStreakLine),
      matching: find.byType(CustomPaint),
    );
    expect(cp, paintsNothing);
  });

  testWidgets('painted: DST range with a non-empty map draws segments', (
    tester,
  ) async {
    final done = <String, bool>{};
    for (var i = 0; i < 10; i++) {
      final d = DateTime(2026, 10, 30 + i);
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      done[key] = true;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 10 * 20,
          height: 24,
          child: HabitStreakLine(
            doneByDay: done,
            dayCount: 10,
            startDate: DateTime(2026, 10, 30),
            cellWidth: 20,
            colorArgb: 0xFF4CAF50,
            weekLevel: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final cp = find.descendant(
      of: find.byType(HabitStreakLine),
      matching: find.byType(CustomPaint),
    );
    expect(cp, paintsExactlyCountTimes(#drawLine, 9));
  });

  testWidgets('painted: reduce motion paints full layout in one pump', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: SizedBox(
            width: 120,
            height: 24,
            child: HabitStreakLine(
              doneByDay: const {'0': true, '1': true, '2': true},
              dayKeys: const ['0', '1', '2'],
              cellWidth: 40,
              colorArgb: 0xFF4CAF50,
              weekLevel: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final cp = find.descendant(
      of: find.byType(HabitStreakLine),
      matching: find.byType(CustomPaint),
    );
    expect(cp, paintsExactlyCountTimes(#drawLine, 2));
  });

  testWidgets('painted: animated case starts empty then completes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 24,
          child: HabitStreakLine(
            doneByDay: const {'0': true, '1': true, '2': true},
            dayKeys: const ['0', '1', '2'],
            cellWidth: 40,
            colorArgb: 0xFF4CAF50,
            weekLevel: false,
            duration: const Duration(milliseconds: 120),
          ),
        ),
      ),
    );
    // Initial frame: progress 0, so nothing is painted yet.
    final cp = find.descendant(
      of: find.byType(HabitStreakLine),
      matching: find.byType(CustomPaint),
    );
    expect(cp, paintsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(cp, paintsExactlyCountTimes(#drawLine, 2));
  });
}
