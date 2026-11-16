import 'package:ephemeron/features/stream/presentation/chrome/breadcrumb.dart';
import 'package:ephemeron/features/stream/presentation/chrome/now_line.dart';
import 'package:ephemeron/features/stream/presentation/chrome/scrubber.dart';
import 'package:ephemeron/features/stream/presentation/chrome/time_rail.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
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
            child: Scrubber(onChanged: values.add, onChangeEnd: (_) {}),
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
            child: Scrubber(onChanged: (_) {}),
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
}
