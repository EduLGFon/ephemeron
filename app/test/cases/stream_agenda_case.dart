import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/presentation/agenda/agenda_lens.dart';
import 'package:ephemeron/features/stream/presentation/agenda/agenda_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

StreamDayMark _mark(String id, int startMs, {String title = 'Title'}) =>
    StreamDayMark(
      id: id,
      kind: StreamDayMarkKind.event,
      startMs: startMs,
      endMs: startMs + 3600000,
      title: title,
      colorArgb: 0xFF1976D2,
    );

void main() {
  test('grouping by day is correct and sorted', () {
    final base = DateTime(2026, 1, 1);
    final m1 = _mark('a', base.millisecondsSinceEpoch + 1000);
    final m2 = _mark('b', base.add(const Duration(days: 1)).millisecondsSinceEpoch + 500);
    final m3 = _mark('c', base.millisecondsSinceEpoch + 500); // same day, earlier
    final secs = groupMarksByDay([m1, m2, m3]);
    expect(secs.length, 2);
    expect(secs[0].items.map((m) => m.id).toList(), ['c', 'a']);
    expect(secs[1].items.map((m) => m.id).toList(), ['b']);
  });

  test('one day with no marks is absent', () {
    final base = DateTime(2026, 1, 1);
    final m = _mark('a', base.millisecondsSinceEpoch);
    final secs = groupMarksByDay([m]);
    expect(secs.length, 1);
  });

  testWidgets('empty input shows empty label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgendaLens(
            marks: const [],
            onMarkTap: (_) {},
            emptyLabel: 'Nothing here',
            formatTime: (_) => '09:00',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('tapping a row calls onMarkTap', (tester) async {
    final base = DateTime(2026, 1, 1);
    final m = _mark('row-1', base.millisecondsSinceEpoch);
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: AgendaLens(
              marks: [m],
              onMarkTap: (id) => tapped = id,
              emptyLabel: 'empty',
              formatTime: (_) => '09:00',
              dayHeadingBuilder: (_) => 'Day',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('row-1')));
    await tester.pump();
    expect(tapped, 'row-1');
  });

  testWidgets('stable keys exist per row', (tester) async {
    final base = DateTime(2026, 1, 1);
    final marks = [for (var i = 0; i < 3; i++) _mark('k$i', base.millisecondsSinceEpoch + i * 1000)];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: AgendaLens(
              marks: marks,
              onMarkTap: (_) {},
              emptyLabel: 'empty',
              formatTime: (_) => '09:00',
              dayHeadingBuilder: (_) => 'Day',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey<String>('k$i')), findsOneWidget);
    }
  });

  testWidgets('500 marks build bounded rows', (tester) async {
    final base = DateTime(2026, 1, 1);
    final marks = [
      for (var i = 0; i < 500; i++)
        _mark('m$i', base.millisecondsSinceEpoch + i * 60000),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 360,
            child: AgendaLens(
              marks: marks,
              onMarkTap: (_) {},
              emptyLabel: 'empty',
              formatTime: (_) => '09:00',
              dayHeadingBuilder: (_) => 'Day',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final built = tester.widgetList(
      find.byWidgetPredicate((w) => w.key is ValueKey<String>),
    ).length;
    expect(built, lessThan(40));
  });

  testWidgets('semantics row labels and headers', (tester) async {
    final base = DateTime(2026, 1, 1);
    final m = _mark('s1', base.millisecondsSinceEpoch, title: 'Hello');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: AgendaLens(
              marks: [m],
              onMarkTap: (_) {},
              emptyLabel: 'empty',
              formatTime: (_) => '09:00',
              semanticLabel: (mm) => '09:00 Hello ${mm.kind.name}',
              dayHeadingBuilder: (_) => 'DayH',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final rowSem = tester.getSemantics(find.byKey(const ValueKey<String>('s1')));
    expect(rowSem.getSemanticsData().label, '09:00 Hello event');
    expect(find.text('DayH'), findsOneWidget);
  });

  testWidgets('320dp at 2.0 scale long title no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = DateTime(2026, 1, 1);
    final m = _mark('l1', base.millisecondsSinceEpoch, title: 'A' * 200);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 600,
              child: AgendaLens(
                marks: [m],
                onMarkTap: (_) {},
                emptyLabel: 'empty',
                formatTime: (_) => '09:00',
                dayHeadingBuilder: (_) => 'Day',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // no exception thrown
  });
}