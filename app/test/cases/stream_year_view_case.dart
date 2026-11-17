import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/presentation/levels/level_data.dart';
import 'package:ephemeron/features/stream/presentation/levels/year_view.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _app({
  required int year,
  Map<String, int> dayCounts = const <String, int>{},
  List<YearHabitStreak> habitStreaks = const <YearHabitStreak>[],
  int firstDayOfWeek = DateTime.monday,
  int? visibleStart,
  int? visibleEnd,
  String? emptyLabel,
  void Function(DateTime date)? onDateTap,
  void Function(String habitId)? onHabitTap,
  void Function(int culledCount)? onCulled,
  double width = 320,
  double height = 600,
  double textScale = 1.0,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: height,
        child: YearView(
          year: year,
          dayCounts: dayCounts,
          habitStreaks: habitStreaks,
          monthHeading: (month) => 'M$month',
          monthSemanticsLabel: (heading, count) => '$heading: $count',
          daySemanticsLabel: (date, count) =>
              'D${date.month}/${date.day}: $count',
          habitStreakSemanticsLabel: (streak, first, last) =>
              '${streak.habitId} ${first.month}/${first.day}-'
              '${last.month}/${last.day}',
          emptyLabel: emptyLabel,
          firstDayOfWeek: firstDayOfWeek,
          visibleMonthStart: visibleStart,
          visibleMonthEnd: visibleEnd,
          onDateTap: onDateTap,
          onHabitTap: onHabitTap,
          onCulledCount: onCulled,
        ),
      ),
    ),
  );
}

StreamDayMark _mark(String id, DateTime date) {
  final start = DateTime(date.year, date.month, date.day, 9);
  return StreamDayMark(
    id: id,
    kind: StreamDayMarkKind.event,
    startMs: start.millisecondsSinceEpoch,
    endMs: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    title: id,
    colorArgb: 0xFF2196F3,
  );
}

Map<String, int> _yearCounts(int year, List<StreamDayMark> marks) {
  final counts = LevelData.countsForRange(
    rangeStart: DateTime(year, 1, 1),
    rangeEnd: DateTime(year, 12, 31),
    marks: marks,
  );
  return <String, int>{
    for (final count in counts) yearDayKey(count.day): count.count,
  };
}

List<SemanticsNode> _semanticsNodes(WidgetTester tester) {
  final root = tester.getSemantics(find.byType(MaterialApp));
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return nodes;
}

bool _isMonthLabel(String label) => RegExp(r'^M\d+: \d+$').hasMatch(label);

void main() {
  testWidgets('normal year renders 12 months', (tester) async {
    final counts = _yearCounts(2026, [_mark('a', DateTime(2026, 3, 15))]);
    await tester.pumpWidget(_app(year: 2026, dayCounts: counts));
    await tester.pump();

    final labels = _semanticsNodes(tester).map((node) => node.label).toList();
    final months = labels.where(_isMonthLabel).toList();
    expect(months.length, 12);
    expect(months, contains('M3: 1'));
    expect(months, contains('M2: 0'));
    expect(months, contains('M12: 0'));
  });

  testWidgets('leap year renders Feb 29 with its count', (tester) async {
    final counts = _yearCounts(2028, [_mark('a', DateTime(2028, 2, 29))]);
    await tester.pumpWidget(_app(year: 2028, dayCounts: counts));
    await tester.pump();

    final labels = _semanticsNodes(tester).map((node) => node.label).toList();
    expect(labels.where(_isMonthLabel).length, 12);
    expect(labels, contains('M2: 1'));
    final feb = buildYearMonthData(year: 2028, month: 2, dayCounts: counts);
    expect(feb.days.length, 29);
    expect(feb.days.last.date, DateTime(2028, 2, 29));
    expect(feb.days.last.count, 1);
  });

  test('month lengths and zero days follow the calendar', () {
    const counts = <String, int>{
      '2026-01-01': 3,
      '2026-02-28': 2,
      '2026-04-30': 1,
    };
    final jan = buildYearMonthData(
      year: 2026,
      month: 1,
      dayCounts: counts,
      maxCount: 3,
    );
    final feb = buildYearMonthData(
      year: 2026,
      month: 2,
      dayCounts: counts,
      maxCount: 3,
    );
    final apr = buildYearMonthData(
      year: 2026,
      month: 4,
      dayCounts: counts,
      maxCount: 3,
    );
    expect(yearDaysInMonth(2026, 2), 28);
    expect(jan.days.length, 31);
    expect(feb.days.length, 28);
    expect(apr.days.length, 30);
    expect(jan.totalCount, 3);
    expect(feb.totalCount, 2);
    expect(apr.totalCount, 1);
    expect(jan.days[1].count, 0);
    expect(jan.days[1].density, 0);
    expect(jan.days[0].density, 1);
  });

  test('density maps counts to the year maximum', () {
    const counts = <String, int>{
      '2026-01-01': 2,
      '2026-01-02': 4,
      '2026-01-03': 0,
    };
    expect(yearMaxDayCount(2026, counts), 4);
    final data = buildYearMonthData(year: 2026, month: 1, dayCounts: counts);
    expect(data.days[0].density, 0.5);
    expect(data.days[1].density, 1.0);
    expect(data.days[2].density, 0.0);
  });

  test('first day of week shifts the grid offset', () {
    expect(
      yearFirstWeekdayOffset(
        year: 2026,
        month: 1,
        firstDayOfWeek: DateTime.monday,
      ),
      3,
    );
    expect(
      yearFirstWeekdayOffset(
        year: 2026,
        month: 1,
        firstDayOfWeek: DateTime.sunday,
      ),
      4,
    );
    expect(
      yearWeekRows(year: 2026, month: 1, firstDayOfWeek: DateTime.monday),
      5,
    );
  });

  test('streak ribbons break on gaps and row wraps', () {
    const gap = YearHabitStreak(
      habitId: 'h1',
      doneDayKeys: {'2026-01-01', '2026-01-02', '2026-01-04'},
    );
    final gapRuns = yearStreakRunsForMonth(
      year: 2026,
      month: 1,
      streak: gap,
      firstDayOfWeek: DateTime.monday,
    );
    expect(gapRuns.map((run) => '${run.firstDay}-${run.lastDay}'), [
      '1-2',
      '4-4',
    ]);

    final row = YearHabitStreak(
      habitId: 'h2',
      doneDayKeys: <String>{
        for (var day = 1; day <= 6; day++) yearDayKey(DateTime(2026, 1, day)),
      },
    );
    final rowRuns = yearStreakRunsForMonth(
      year: 2026,
      month: 1,
      streak: row,
      firstDayOfWeek: DateTime.monday,
    );
    expect(rowRuns.map((run) => '${run.firstDay}-${run.lastDay}'), [
      '1-4',
      '5-6',
    ]);
  });

  testWidgets('visible month range culls paint and reports the count', (
    tester,
  ) async {
    int? culled;
    await tester.pumpWidget(
      _app(
        year: 2026,
        visibleStart: 3,
        visibleEnd: 8,
        onCulled: (value) => culled = value,
      ),
    );
    await tester.pump();

    expect(culled, 6);
    final labels = _semanticsNodes(tester).map((node) => node.label).toList();
    final months = labels.where(_isMonthLabel).toList();
    expect(months.length, 6);
    expect(months.any((label) => label.startsWith('M3: ')), isTrue);
    expect(months.any((label) => label.startsWith('M8: ')), isTrue);
    expect(months.any((label) => label.startsWith('M1: ')), isFalse);
    expect(months.any((label) => label.startsWith('M9: ')), isFalse);

    final culledGeometry = buildYearViewGeometry(
      year: 2026,
      width: 320,
      textScale: 1,
      dayCounts: const <String, int>{},
      habitStreaks: const <YearHabitStreak>[],
      firstDayOfWeek: DateTime.monday,
      visibleMonthStart: 3,
      visibleMonthEnd: 8,
    );
    final fullGeometry = buildYearViewGeometry(
      year: 2026,
      width: 320,
      textScale: 1,
      dayCounts: const <String, int>{},
      habitStreaks: const <YearHabitStreak>[],
      firstDayOfWeek: DateTime.monday,
    );
    expect(culledGeometry.months.map((month) => month.month), [
      3,
      4,
      5,
      6,
      7,
      8,
    ]);
    expect(culledGeometry.size.height, lessThan(fullGeometry.size.height));
  });

  testWidgets('tap maps to a date', (tester) async {
    DateTime? tapped;
    final geometry = buildYearViewGeometry(
      year: 2026,
      width: 320,
      textScale: 1,
      dayCounts: const <String, int>{},
      habitStreaks: const <YearHabitStreak>[],
      firstDayOfWeek: DateTime.monday,
    );
    await tester.pumpWidget(
      _app(year: 2026, onDateTap: (date) => tapped = date),
    );
    await tester.pump();

    await tester.tapAt(geometry.months.first.days.first.rect.center);
    await tester.pump();
    expect(tapped, DateTime(2026, 1, 1));
  });

  testWidgets('tap maps to a habit id', (tester) async {
    String? tappedHabit;
    DateTime? tappedDate;
    const streak = YearHabitStreak(
      habitId: 'h1',
      doneDayKeys: {'2026-01-01', '2026-01-02'},
    );
    final geometry = buildYearViewGeometry(
      year: 2026,
      width: 320,
      textScale: 1,
      dayCounts: const <String, int>{},
      habitStreaks: const <YearHabitStreak>[streak],
      firstDayOfWeek: DateTime.monday,
    );
    await tester.pumpWidget(
      _app(
        year: 2026,
        habitStreaks: const <YearHabitStreak>[streak],
        onDateTap: (date) => tappedDate = date,
        onHabitTap: (id) => tappedHabit = id,
      ),
    );
    await tester.pump();

    await tester.tapAt(geometry.months.first.streaks.first.rect.center);
    await tester.pump();
    expect(tappedHabit, 'h1');
    expect(tappedDate, isNull);
  });

  testWidgets('habit hit without callback falls through to date', (
    tester,
  ) async {
    DateTime? tapped;
    const streak = YearHabitStreak(
      habitId: 'h1',
      doneDayKeys: {'2026-01-01', '2026-01-02'},
    );
    final geometry = buildYearViewGeometry(
      year: 2026,
      width: 320,
      textScale: 1,
      dayCounts: const <String, int>{},
      habitStreaks: const <YearHabitStreak>[streak],
      firstDayOfWeek: DateTime.monday,
    );
    await tester.pumpWidget(
      _app(
        year: 2026,
        habitStreaks: const <YearHabitStreak>[streak],
        onDateTap: (date) => tapped = date,
      ),
    );
    await tester.pump();

    await tester.tapAt(geometry.months.first.streaks.first.rect.center);
    await tester.pump();
    expect(tapped, isNotNull);
  });

  testWidgets('semantics expose month and streak nodes with tap actions', (
    tester,
  ) async {
    const streak = YearHabitStreak(
      habitId: 'h1',
      doneDayKeys: {'2026-01-01', '2026-01-02'},
    );
    await tester.pumpWidget(
      _app(
        year: 2026,
        habitStreaks: const <YearHabitStreak>[streak],
        onDateTap: (_) {},
        onHabitTap: (_) {},
      ),
    );
    await tester.pump();

    final nodes = _semanticsNodes(tester);
    final monthNodes = nodes
        .where((node) => _isMonthLabel(node.label))
        .toList();
    final dayNodes = nodes
        .where((node) => node.label.startsWith('D1/1: '))
        .toList();
    final streakNodes = nodes
        .where((node) => node.label.startsWith('h1 '))
        .toList();
    expect(monthNodes.length, 12);
    expect(
      monthNodes.every(
        (node) => node.getSemanticsData().hasAction(SemanticsAction.tap),
      ),
      isTrue,
    );
    expect(dayNodes, isNotEmpty);
    expect(
      dayNodes.every(
        (node) => node.getSemanticsData().hasAction(SemanticsAction.tap),
      ),
      isTrue,
    );
    expect(streakNodes, isNotEmpty);
    expect(
      streakNodes.every(
        (node) => node.getSemanticsData().hasAction(SemanticsAction.tap),
      ),
      isTrue,
    );
  });

  testWidgets('semantics omit tap actions without callbacks', (tester) async {
    const streak = YearHabitStreak(
      habitId: 'h1',
      doneDayKeys: {'2026-01-01', '2026-01-02'},
    );
    await tester.pumpWidget(
      _app(year: 2026, habitStreaks: const <YearHabitStreak>[streak]),
    );
    await tester.pump();

    final nodes = _semanticsNodes(tester);
    final monthNodes = nodes
        .where((node) => _isMonthLabel(node.label))
        .toList();
    final streakNodes = nodes
        .where((node) => node.label.startsWith('h1 '))
        .toList();
    expect(monthNodes.length, 12);
    expect(
      monthNodes.every(
        (node) => !node.getSemanticsData().hasAction(SemanticsAction.tap),
      ),
      isTrue,
    );
    expect(streakNodes, isNotEmpty);
    expect(
      streakNodes.every(
        (node) => !node.getSemanticsData().hasAction(SemanticsAction.tap),
      ),
      isTrue,
    );
  });

  testWidgets('320 dp at 2.0 text scale does not overflow', (tester) async {
    final counts = <String, int>{
      for (var month = 1; month <= 12; month++)
        yearDayKey(DateTime(2026, month, 1)): 7,
    };
    await tester.pumpWidget(
      _app(year: 2026, dayCounts: counts, textScale: 2.0),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(YearView)).width, lessThanOrEqualTo(320));
    final months = _semanticsNodes(tester)
        .where((node) => _isMonthLabel(node.label))
        .length;
    expect(months, 12);
  });

  testWidgets('empty year renders the caller empty label', (tester) async {
    await tester.pumpWidget(_app(year: 2026, emptyLabel: 'Nothing this year'));
    await tester.pump();

    expect(find.text('Nothing this year'), findsOneWidget);
    expect(
      _semanticsNodes(tester).where((node) => _isMonthLabel(node.label)),
      isEmpty,
    );
  });
}
