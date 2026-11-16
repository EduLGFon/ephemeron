import 'package:ephemeron/features/stream/presentation/chrome/breadcrumb.dart';
import 'package:ephemeron/features/stream/presentation/chrome/now_line.dart';
import 'package:ephemeron/features/stream/presentation/chrome/scrubber.dart';
import 'package:ephemeron/features/stream/presentation/chrome/time_rail.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NowLine label updates without rebuilding parent', (
    tester,
  ) async {
    final label = ValueNotifier<String>('10:00');
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, _) {
            builds++;
            return Scaffold(body: NowLine(label: label));
          },
        ),
      ),
    );
    final initialBuilds = builds;
    label.value = '10:01';
    await tester.pump();
    expect(find.text('10:01'), findsOneWidget);
    expect(builds, initialBuilds);
  });

  testWidgets('TimeRail builds only visible labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 200,
          width: 60,
          child: TimeRail(
            hourCount: 1000,
            hourHeight: 40,
            viewportHeight: 200,
            hourLabelBuilder: (i) => 'H$i',
          ),
        ),
      ),
    );
    await tester.pump();
    final found = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').startsWith('H'),
    );
    expect(found, findsWidgets);
    expect(tester.widgetList(found).length, lessThanOrEqualTo(8));
  });

  testWidgets('Breadcrumb tap calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Breadcrumb(
            dateLabel: 'Mon 16 Nov',
            levelLabel: 'Day',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Breadcrumb));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('disabled Breadcrumb does not call onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Breadcrumb(dateLabel: 'Mon 16 Nov', levelLabel: 'Day'),
        ),
      ),
    );
    await tester.tap(find.byType(Breadcrumb), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('Breadcrumb Semantics label present', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Breadcrumb(
            dateLabel: 'Mon 16 Nov',
            levelLabel: 'Day',
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Mon 16 Nov, Day'), findsOneWidget);
  });

  testWidgets('Scrubber drag reports clamped values', (tester) async {
    final values = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            width: 60,
            child: Scrubber(
              semanticLabel: 'position',
              valueFormatter: (v) => '${(v * 100).round()}%',
              onChanged: values.add,
              onChangeEnd: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(Scrubber), const Offset(0, 1000));
    await tester.pump();
    expect(values, isNotEmpty);
    for (final v in values) {
      expect(v, greaterThanOrEqualTo(0));
      expect(v, lessThanOrEqualTo(1));
    }
    expect(values.last, 1.0);
  });

  testWidgets('Scrubber semantics increase/decrease exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            width: 60,
            child: Scrubber(
              semanticLabel: 'position',
              valueFormatter: (v) => '${(v * 100).round()}%',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final semanticsFinder = find.descendant(
      of: find.byType(Scrubber),
      matching: find.byType(Semantics),
    );
    final semantics = tester.getSemantics(semanticsFinder);
    final data = semantics.getSemanticsData();
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
  });

  testWidgets('Breadcrumb semantics label and value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Breadcrumb(
            dateLabel: 'Mon 16 Nov',
            levelLabel: 'Day',
            onTap: () {},
          ),
        ),
      ),
    );
    final data = tester
        .getSemantics(find.byType(Breadcrumb))
        .getSemanticsData();
    expect(data.label, 'Mon 16 Nov, Day');
  });

  testWidgets('Scrubber semantics label and value string', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            width: 60,
            child: Scrubber(
              semanticLabel: 'position',
              valueFormatter: (v) => '${(v * 100).round()}%',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final semanticsFinder = find.descendant(
      of: find.byType(Scrubber),
      matching: find.byType(Semantics),
    );
    final data = tester.getSemantics(semanticsFinder).getSemanticsData();
    expect(data.label, 'position');
    expect(data.value, '0%');
  });

  testWidgets('Breadcrumb long label does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: Breadcrumb(
                dateLabel: 'A very long date label that should ellipsize instead of overflowing the available width',
                levelLabel: 'Level',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Breadcrumb focus ring and Enter activates', (tester) async {
    var taps = 0;
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Breadcrumb(
            dateLabel: 'Mon 16 Nov',
            levelLabel: 'Day',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    // find the breadcrumb's focus node indirectly by requesting via tree
    final breadcrumb = tester.widget<Breadcrumb>(find.byType(Breadcrumb));
    expect(breadcrumb, isNotNull);
    final inkWell = find.descendant(
      of: find.byType(Breadcrumb),
      matching: find.byType(InkWell),
    );
    final renderBefore = (tester.renderObject(inkWell) as RenderBox).size;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    final renderAfter = (tester.renderObject(inkWell) as RenderBox).size;
    expect(renderAfter, renderBefore);
  });

  testWidgets('Breadcrumb hover changes state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Breadcrumb(
            dateLabel: 'Mon 16 Nov',
            levelLabel: 'Day',
            onTap: () {},
          ),
        ),
      ),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byType(Breadcrumb)));
    await tester.pump();
    await gesture.removePointer();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Breadcrumb and Scrubber 48dp targets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Breadcrumb(dateLabel: 'Mon', levelLabel: 'Day', onTap: () {}),
              SizedBox(
                height: 200,
                width: 60,
                child: Scrubber(semanticLabel: 'position', onChanged: (_) {}),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final bSize =
        (tester.renderObject(find.byType(Breadcrumb)) as RenderBox).size;
    final sSize =
        (tester.renderObject(find.byType(Scrubber)) as RenderBox).size;
    expect(bSize.width, greaterThanOrEqualTo(48));
    expect(bSize.height, greaterThanOrEqualTo(48));
    expect(sSize.width, greaterThanOrEqualTo(48));
    expect(sSize.height, greaterThanOrEqualTo(48));
  });
}
