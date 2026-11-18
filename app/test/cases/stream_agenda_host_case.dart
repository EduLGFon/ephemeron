import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_agenda_host.dart';
import 'package:flutter/semantics.dart';
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

Widget _app({
  required List<StreamDayMark> marks,
  void Function(String id)? onMarkTap,
  double width = 400,
  double height = 700,
  double textScale = 1.0,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: StreamAgendaHost(
            marks: marks,
            emptyLabel: 'No marks',
            formatTime: (ms) => 'T$ms',
            semanticLabel: (mark) => '${mark.title} mark',
            dayHeadingBuilder: (day) => 'Day ${day.day}',
            onMarkTap: onMarkTap ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  final base = DateTime(2026, 3, 10);

  testWidgets('two days give two caller headings with sorted rows', (
    tester,
  ) async {
    final marks = [
      _mark('late', base.add(const Duration(hours: 10)).millisecondsSinceEpoch),
      _mark('early', base.add(const Duration(hours: 8)).millisecondsSinceEpoch),
      _mark(
        'next',
        base.add(const Duration(days: 1, hours: 9)).millisecondsSinceEpoch,
      ),
    ];
    await tester.pumpWidget(_app(marks: marks));
    await tester.pump();

    expect(find.text('Day 10'), findsOneWidget);
    expect(find.text('Day 11'), findsOneWidget);
    final earlyY = tester.getTopLeft(find.byKey(const ValueKey('early'))).dy;
    final lateY = tester.getTopLeft(find.byKey(const ValueKey('late'))).dy;
    expect(earlyY, lessThan(lateY));
  });

  testWidgets('empty marks show the caller empty label', (tester) async {
    await tester.pumpWidget(_app(marks: const []));
    await tester.pump();

    expect(find.text('No marks'), findsOneWidget);
  });

  testWidgets('tapping a row reports its id', (tester) async {
    String? tapped;
    final marks = [
      _mark('row-1', base.add(const Duration(hours: 8)).millisecondsSinceEpoch),
    ];
    await tester.pumpWidget(_app(marks: marks, onMarkTap: (id) => tapped = id));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('row-1')));
    await tester.pump();

    expect(tapped, 'row-1');
  });

  testWidgets('500 marks build a bounded number of rows', (tester) async {
    final marks = [
      for (var i = 0; i < 500; i++)
        _mark('m$i', base.millisecondsSinceEpoch + i * 60000),
    ];
    await tester.pumpWidget(_app(marks: marks));
    await tester.pump();

    final built = tester
        .widgetList(find.byWidgetPredicate((w) => w.key is ValueKey<String>))
        .length;
    expect(built, lessThanOrEqualTo(10));
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final marks = [
      _mark('long', base.millisecondsSinceEpoch, title: 'A' * 200),
    ];
    await tester.pumpWidget(
      _app(marks: marks, width: 320, height: 640, textScale: 2.0),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('rows are buttons and day headings are headers', (tester) async {
    final marks = [
      _mark(
        's1',
        base.add(const Duration(hours: 9)).millisecondsSinceEpoch,
        title: 'Hello',
      ),
    ];
    await tester.pumpWidget(_app(marks: marks));
    await tester.pump();

    final row = tester
        .getSemantics(find.byKey(const ValueKey('s1')))
        .getSemanticsData();
    expect(row.label, 'Hello mark');
    expect(row.flagsCollection.isButton, isTrue);
    expect(row.hasAction(SemanticsAction.tap), isTrue);
    final header = tester.getSemantics(find.text('Day 10')).getSemanticsData();
    expect(header.flagsCollection.isHeader, isTrue);
  });
}
