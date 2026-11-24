import 'package:ephemeron/core/design/components/rows.dart';
import 'package:ephemeron/core/design/components/visuals.dart';
import 'package:ephemeron/core/design/theme.dart';
import 'package:ephemeron/core/design/tokens.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fixtures.dart';

import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child, {double textScale = 1, bool reduceMotion = false}) {
  return MaterialApp(
    theme: EphemeronTheme.build(
      mode: 'light',
      platformBrightness: Brightness.light,
    ),
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: appChild!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DsSpace.x8),
        child: child,
      ),
    ),
  );
}

SemanticsData _data(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();

Finder _sem(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

const _week = <bool>[true, false, true, true, false, true, false];

void main() {
  testWidgets('every data component renders', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTaskRow(
              title: 'Write report',
              subtitle: 'Work',
              listColor: Colors.blue,
              priority: 2,
              overdue: true,
              onTap: () {},
              onToggle: () {},
            ),
            const AppEventRow(
              title: 'Standup',
              timeLabel: '09:00',
              location: 'Room 3',
              color: Colors.teal,
            ),
            const AppHabitChip(name: 'Meditate', progress: 0.5),
            const AppHabitRow(
              name: 'Run',
              progress: 1,
              done: true,
              streakLabel: '4 days',
              weekDots: _week,
            ),
            const AppCountdownCard(
              title: 'Launch',
              days: 12,
              dateLabel: 'Mar 4',
              yearly: true,
            ),
            const AppProgressRing(value: 0.42, semanticsLabel: 'Progress'),
            const AppHeatmap(
              values: <double>[0.2, 0.5, 0.8, 1],
              semanticsLabel: 'Habit heatmap',
            ),
            const AppCheckmark(checked: true),
          ],
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Write report'), findsOneWidget);
    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('Meditate'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(find.text('Launch'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('completed, overdue, priority and dense task states', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AppTaskRow(
          title: 'Finished',
          subtitle: 'Due yesterday',
          completed: true,
          overdue: true,
          priority: 1,
          dense: true,
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('Finished'));
    expect(title.style?.decoration, TextDecoration.lineThrough);
    // Overdue is conveyed by a red date label, not a separate tag.
    expect(find.text('Overdue'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    final date = tester.widget<Text>(find.text('Due yesterday'));
    expect(
      date.style?.color,
      Theme.of(tester.element(find.byType(AppTaskRow))).colorScheme.error,
    );
    expect(find.byIcon(Icons.flag), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^P[1-4]$').hasMatch(w.data ?? ''),
      ),
      findsNothing,
    );
    expect(title.style?.fontSize, lessThan(16));

    await tester.pumpWidget(_wrap(const AppTaskRow(title: 'Quiet')));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && RegExp(r'^P[1-4]$').hasMatch(widget.data ?? ''),
      ),
      findsNothing,
    );
    expect(find.text('Overdue'), findsNothing);
  });

  testWidgets('checkbox tap does not also fire the row tap', (tester) async {
    var toggles = 0;
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 320,
          child: AppTaskRow(
            title: 'Check me',
            onTap: () => taps++,
            onToggle: () => toggles++,
          ),
        ),
      ),
    );
    final row = find.byType(AppTaskRow);
    await tester.tapAt(
      tester.getTopLeft(row) + Offset(24, tester.getSize(row).height / 2),
    );
    await settle(tester);
    expect(toggles, 1);
    expect(taps, 0);

    await tester.tap(find.text('Check me'));
    await settle(tester);
    expect(taps, 1);
    expect(toggles, 1);
  });

  testWidgets('task and habit semantics expose checked and toggled states', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var done = false;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              AppTaskRow(
                title: 'Check me',
                completed: done,
                onToggle: () => setState(() => done = true),
              ),
              const AppHabitChip(
                name: 'Meditate',
                progress: 1,
                done: true,
                onTap: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      _data(tester, _sem('Mark complete')).flagsCollection.isChecked.name,
      'isFalse',
    );
    await tester.tap(_sem('Mark complete'));
    await settle(tester);
    expect(
      _data(tester, _sem('Mark incomplete')).flagsCollection.isChecked.name,
      'isTrue',
    );
    final habit = _data(tester, _sem('Meditate, 100%'));
    expect(habit.flagsCollection.isToggled.name, 'isTrue');
    expect(habit.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('countdown handles zero, negative and compact days', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Column(
          children: [
            AppCountdownCard(title: 'Today', days: 0),
            AppCountdownCard(title: 'Past', days: -4, compact: true),
          ],
        ),
      ),
    );
    expect(find.text('0'), findsOneWidget);
    expect(find.text('-4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress ring clamps values and repaints on a listenable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(const AppProgressRing(value: -0.5, semanticsLabel: 'Ring')),
    );
    expect(_data(tester, _sem('Ring')).value, '0%');
    await tester.pumpWidget(
      _wrap(const AppProgressRing(value: 1.5, semanticsLabel: 'Ring')),
    );
    await settle(tester);
    expect(_data(tester, _sem('Ring')).value, '100%');
    expect(
      find.descendant(
        of: find.byType(AppProgressRing),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );

    final repaint = ValueNotifier<int>(0);
    addTearDown(repaint.dispose);
    await tester.pumpWidget(
      _wrap(AppProgressRing(value: 0.4, repaint: repaint)),
    );
    repaint.value++;
    await tester.pump();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('heatmap summarizes values and reports tapped days', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var tapped = -1;
    await tester.pumpWidget(
      _wrap(
        const AppHeatmap(values: <double>[], semanticsLabel: 'Empty heatmap'),
      ),
    );
    expect(_data(tester, _sem('Empty heatmap')).value, '0/112');
    expect(
      find.descendant(
        of: find.byType(AppHeatmap),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );

    await tester.pumpWidget(
      _wrap(
        AppHeatmap(
          values: const <double>[0, 0.5, 1, 0, 0, 0, 0],
          semanticsLabel: 'Habit heatmap',
          onTapDay: (index) => tapped = index,
        ),
      ),
    );
    expect(_data(tester, _sem('Habit heatmap')).value, '2/7');
    final origin = tester.getTopLeft(find.byType(AppHeatmap));
    await tester.tapAt(origin + const Offset(6, 36));
    expect(tapped, 2);
    handle.dispose();
  });

  testWidgets('checkmark exposes checked and unchecked semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const AppCheckmark(checked: false)));
    expect(
      _data(tester, find.byType(AppCheckmark)).flagsCollection.isChecked.name,
      'isFalse',
    );
    await tester.pumpWidget(_wrap(const AppCheckmark(checked: true)));
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester);
    expect(
      _data(tester, find.byType(AppCheckmark)).flagsCollection.isChecked.name,
      'isTrue',
    );
    handle.dispose();
  });

  testWidgets('320dp at 200 percent text does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _wrap(
        textScale: 2,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTaskRow(
              title: 'A very long task title that needs two lines and more',
              subtitle: 'A long subtitle that will ellipsize in narrow rows',
              priority: 4,
              overdue: true,
              leading: const Icon(Icons.label_outline),
              trailing: const Icon(Icons.more_horiz),
              onTap: _noop,
              onToggle: _noop,
            ),
            AppEventRow(
              title: 'A long event title that wraps over two lines',
              timeLabel: '09:00 - 10:30',
              location: 'A long location name that must ellipsize cleanly',
              trailing: const Icon(Icons.videocam_outlined),
              onTap: _noop,
            ),
            const AppHabitChip(
              name: 'Meditate for a very long time',
              progress: 0.75,
              onTap: _noop,
            ),
            AppHabitRow(
              name: 'A habit with a long name at large text',
              subtitle: 'Thirty minutes every single morning',
              progress: 0.66,
              streakLabel: '12 day streak',
              weekDots: _week,
              trailing: const Icon(Icons.more_horiz),
              onTap: _noop,
            ),
            AppCountdownCard(
              title: 'A very long countdown title for the expanded layout',
              days: 1234,
              dateLabel: 'Wednesday, November 18, 2026',
              yearly: true,
              onTap: _noop,
            ),
            const AppCountdownCard(
              title: 'Compact countdown',
              days: -12,
              dateLabel: 'Long date label',
              compact: true,
              yearly: true,
            ),
            const AppProgressRing(value: 0.5, child: Text('50%')),
            AppHeatmap(
              values: List<double>.generate(112, (index) => (index % 5) / 4),
            ),
            const AppCheckmark(checked: true),
          ],
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion settles the checkmark and ring immediately', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(const AppCheckmark(checked: false), reduceMotion: true),
    );
    await tester.pumpWidget(
      _wrap(const AppCheckmark(checked: true), reduceMotion: true),
    );
    await settle(tester);
    expect(
      _data(tester, find.byType(AppCheckmark)).flagsCollection.isChecked.name,
      'isTrue',
    );

    await tester.pumpWidget(
      _wrap(
        const AppProgressRing(value: 0.1, semanticsLabel: 'Ring'),
        reduceMotion: true,
      ),
    );
    await tester.pumpWidget(
      _wrap(
        const AppProgressRing(value: 0.9, semanticsLabel: 'Ring'),
        reduceMotion: true,
      ),
    );
    await settle(tester);
    expect(_data(tester, _sem('Ring')).value, '90%');
    handle.dispose();
  });
}

void _noop() {}
