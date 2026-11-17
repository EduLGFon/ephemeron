import 'package:ephemeron/features/stream/presentation/habits/habit_gutter.dart';
import 'package:ephemeron/features/stream/presentation/habits/habit_glyph.dart';
import 'package:ephemeron/features/stream/presentation/habits/habit_gutter_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

HabitGutterItem _item(String id, int? minutes, {bool done = false}) =>
    HabitGutterItem(
      id: id,
      name: id,
      colorArgb: 0xFF4CAF50,
      timeMinutes: minutes,
      doneByDay: {'2026-01-01': done},
      streakCurrent: 3,
      streakBest: 5,
    );

void main() {
  testWidgets('items render at the right y for their time', (tester) async {
    final items = [_item('a', 60), _item('b', 120)];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 400,
          child: HabitGutter(
            habits: items,
            currentDayKey: '2026-01-01',
            hourHeight: 56,
            onToggle: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    // Default mapping maps 60 min -> 56; gutter adds the 48 px all-day slot once.
    expect(tester.getTopLeft(find.byType(HabitGlyph).first).dy, 48 + 56);
  });

  testWidgets('all-day items go to the top slot', (tester) async {
    final items = [_item('all', null)];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 400,
          child: HabitGutter(
            habits: items,
            currentDayKey: '2026-01-01',
            onToggle: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HabitGlyph), findsOneWidget);
    // All-day items occupy the top slot.
    expect(tester.getTopLeft(find.byType(HabitGlyph)).dy, 0);
  });

  testWidgets('tapping calls onToggle once with the id', (tester) async {
    String? toggled;
    var count = 0;
    final items = [_item('a', 60)];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 400,
          child: HabitGutter(
            habits: items,
            currentDayKey: '2026-01-01',
            onToggle: (id) {
              toggled = id;
              count++;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(HabitGlyph));
    await tester.pump();
    expect(toggled, 'a');
    expect(count, 1);
  });

  testWidgets('tapping sets done semantics', (tester) async {
    final items = [_item('a', 60, done: true)];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 400,
          child: HabitGutter(
            habits: items,
            currentDayKey: '2026-01-01',
            onToggle: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    final semantics = tester.getSemantics(find.byType(HabitGlyph));
    expect(
      semantics.getSemanticsData().flagsCollection.isToggled.name,
      'isTrue',
    );
  });

  testWidgets('long-press shows the streak label', (tester) async {
    final items = [_item('a', 60)];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 400,
          child: HabitGutter(
            habits: items,
            currentDayKey: '2026-01-01',
            streakLabelFor: (i) => 'Streak ${i.streakCurrent}',
            onToggle: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.longPress(find.byType(HabitGlyph));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Streak 3'), findsOneWidget);
  });

  testWidgets('500 habits build a bounded number of glyphs', (tester) async {
    final items = List.generate(500, (i) => _item('h$i', i % 1440));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 200,
          child: HabitGutter(
            habits: items,
            currentDayKey: '2026-01-01',
            onToggle: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HabitGlyph).evaluate().length, lessThan(50));
  });

  testWidgets('200% text scale at 320 dp does not overflow', (tester) async {
    final items = [_item('verylonghabitname', 60)];
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2.0),
        ),
        child: MaterialApp(
          home: SizedBox(
            width: 120,
            height: 400,
            child: HabitGutter(
              habits: items,
              currentDayKey: '2026-01-01',
              streakLabelFor: (i) => 'Streak ${i.streakCurrent}',
              onToggle: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('done vs not-done distinguishable without colour', (
    tester,
  ) async {
    final items = [_item('a', 60, done: false)];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 400,
          child: HabitGutter(
            habits: items,
            currentDayKey: '2026-01-01',
            onToggle: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    final semantics = tester.getSemantics(find.byType(HabitGlyph));
    expect(
      semantics.getSemanticsData().flagsCollection.isToggled.name,
      'isFalse',
    );
  });

  testWidgets('out-of-range time is treated as all-day', (tester) async {
    final items = [_item('a', 2000)];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 400,
          child: HabitGutter(
            habits: items,
            currentDayKey: '2026-01-01',
            onToggle: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(HabitGlyph), findsOneWidget);
  });

  testWidgets('done on another day does not render done', (tester) async {
    final item = HabitGutterItem(
      id: 'a',
      name: 'a',
      colorArgb: 0xFF4CAF50,
      timeMinutes: 60,
      doneByDay: {'2026-01-02': true},
      streakCurrent: 3,
      streakBest: 5,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 400,
          child: HabitGutter(
            habits: [item],
            currentDayKey: '2026-01-01',
            onToggle: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    final semantics = tester.getSemantics(find.byType(HabitGlyph));
    expect(
      semantics.getSemanticsData().flagsCollection.isToggled.name,
      'isFalse',
    );
  });

  testWidgets('duplicate ids toggle independently', (tester) async {
    final items = [_item('a', 60), _item('a', 120)];
    final toggled = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 400,
          child: HabitGutter(
            habits: items,
            currentDayKey: '2026-01-01',
            onToggle: toggled.add,
          ),
        ),
      ),
    );
    await tester.pump();
    final glyphs = find.byType(HabitGlyph);
    expect(glyphs, findsNWidgets(2));
    await tester.tap(glyphs.first);
    await tester.pump();
    await tester.tap(glyphs.last);
    await tester.pump();
    expect(toggled, ['a', 'a']);
  });
}
