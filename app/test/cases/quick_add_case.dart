import 'package:ephemeron/core/design/components/app_wheel.dart';
import 'package:ephemeron/domain/parsing/quick_add_parser.dart';
import 'package:ephemeron/domain/tasks/eisenhower.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('shorthands extracted, rest parsed for date', () {
    final p = parseQuickAdd(
      'Buy milk #groceries ~home -p1 tomorrow 9h',
      now: DateTime(2026, 3, 2, 8),
    );
    expect(p.title, 'Buy milk');
    expect(p.tags, ['groceries']);
    expect(p.list, 'home');
    expect(p.priority, 4);
    expect(p.due, DateTime(2026, 3, 3, 9));
  });

  test('plain title stays intact', () {
    final p = parseQuickAdd('Read a book', now: DateTime(2026, 3, 2, 8));
    expect(p.title, 'Read a book');
    expect(p.tags, isEmpty);
    expect(p.priority, 0);
    expect(p.due, isNull);
  });

  test('recurrence phrases produce rrule', () {
    final p = parseQuickAdd('Gym todo dia 8h', now: DateTime(2026, 3, 2, 8));
    expect(p.rrule, 'FREQ=DAILY');
    expect(p.due, DateTime(2026, 3, 2, 8));
  });

  testWidgets('WheelSelector renders items and reports selection', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WheelSelector<int>(
            items: const <WheelItem<int>>[
              WheelItem<int>(
                value: 0,
                label: 'None',
                icon: Icons.flag_outlined,
                key: ValueKey('wheel-0'),
              ),
              WheelItem<int>(
                value: 1,
                label: 'P1',
                icon: Icons.flag,
                color: Color(0xFFD32F2F),
                key: ValueKey('wheel-1'),
              ),
            ],
            value: 0,
            onChanged: (value) => selected = value,
            semanticsLabel: 'Priority',
          ),
        ),
      ),
    );

    expect(find.text('None'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wheel-1')));
    await tester.pump();
    expect(selected, 1);
  });

  testWidgets('AppPriorityFlag renders flag icon only and hides none', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              AppPriorityFlag(flag: PriorityFlag.p1),
              AppPriorityFlag(flag: PriorityFlag.none),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.flag), findsOneWidget);
    expect(find.text('P1'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^P[1-4]$').hasMatch(w.data ?? ''),
      ),
      findsNothing,
    );
    // PriorityFlag.none renders nothing.
    expect(find.text('None'), findsNothing);
  });

  test('priority flag mapping is stable', () {
    expect(priorityFlag(4), PriorityFlag.p1);
    expect(priorityFlag(1), PriorityFlag.p4);
    expect(priorityFlag(0), PriorityFlag.none);
    expect(priorityFlagValue(PriorityFlag.p1), 4);
    expect(visualPriority(4), 1);
    expect(storedPriority(1), 4);
  });
}
