import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/stream/application/stream_day_cache.dart';
import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/application/stream_level_data.dart';
import 'package:ephemeron/features/stream/presentation/levels/month_view.dart';
import 'package:ephemeron/features/stream/presentation/levels/week_view.dart';
import 'package:ephemeron/features/stream/presentation/surface/stream_level_host.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _RecordingController extends StreamDayCacheController {
  final List<CalendarRange> calls = <CalendarRange>[];

  @override
  Future<void> ensure(CalendarRange requested) async {
    calls.add(requested);
  }
}

StreamDayMark _mark(String id, DateTime localStart) {
  final startMs = localStart.millisecondsSinceEpoch;
  return StreamDayMark(
    id: id,
    kind: StreamDayMarkKind.event,
    startMs: startMs,
    endMs: startMs + const Duration(hours: 1).inMilliseconds,
    title: id,
    colorArgb: 0xFF2196F3,
  );
}

StreamLevelMarks _marks(List<StreamDayMark> marks, {bool covered = true}) =>
    StreamLevelMarks(marks: marks, skipped: 0, covered: covered);

Widget _hostApp({
  required StreamLevel level,
  required DateTime date,
  required StreamLevelMarks marks,
  List<Override> overrides = const <Override>[],
  int firstDayOfWeek = DateTime.monday,
  List<MonthHabitStreak>? habitStreaks,
  void Function(DateTime date)? onDayTap,
  void Function(String markId)? onMarkTap,
  void Function(DateTime date)? onDateTap,
  void Function(CalendarRange range)? ensureRange,
  double width = 320,
  double height = 400,
  double textScale = 1.0,
}) {
  final range = streamLevelRangeFor(level, date);
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      streamLevelMarksProvider(range).overrideWithValue(AsyncData(marks)),
      ...overrides,
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: StreamLevelHost(
            level: level,
            date: date,
            firstDayOfWeek: firstDayOfWeek,
            dayHeaderBuilder: (index, day) => 'D${day.day}',
            daySemanticsLabel: (index, day) => 'Day ${day.day}',
            monthDaySemanticsLabel: (day, count) => 'Day $day: $count',
            streakSemanticsLabel: (streak, first, last) =>
                '${streak.habitId} $first-$last',
            markSemanticsLabel: (mark) => mark.title,
            markActionLabels: const {
              'complete': 'Done',
              'push': 'Push',
              'reschedule': 'Reschedule',
              'delete': 'Delete',
            },
            emptyLabel: 'Nothing here',
            loadingLabel: 'Loading marks',
            errorLabel: 'Could not load marks',
            habitStreaks: habitStreaks,
            onDayTap: onDayTap,
            onMarkTap: onMarkTap,
            onDateTap: onDateTap,
            ensureRange: ensureRange,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('week: covered marks render WeekView with caller headings', (
    tester,
  ) async {
    final date = DateTime(2026, 11, 18);
    String? tappedMark;
    DateTime? tappedDay;
    await tester.pumpWidget(
      _hostApp(
        level: StreamLevel.week,
        date: date,
        marks: _marks([
          _mark('a', DateTime(2026, 11, 17, 9)),
          _mark('b', DateTime(2026, 11, 17, 11)),
          _mark('c', DateTime(2026, 11, 18, 9)),
        ]),
        onMarkTap: (id) => tappedMark = id,
        onDayTap: (day) => tappedDay = day,
      ),
    );
    await tester.pump();

    expect(find.byType(WeekView), findsOneWidget);
    final view = tester.widget<WeekView>(find.byType(WeekView));
    expect(view.weekStart, DateTime(2026, 11, 16));
    expect(view.dayHeaderBuilder(0, DateTime(2026, 11, 16)), 'D16');
    expect(view.dayHeaderBuilder(2, DateTime(2026, 11, 18)), 'D18');
    expect(view.dayMarks![1].map((mark) => mark.id), ['a', 'b']);
    expect(view.dayMarks![2].map((mark) => mark.id), ['c']);

    final topLeft = tester.getTopLeft(find.byType(WeekView));
    await tester.tapAt(topLeft + Offset(view.cellWidth * 1.5, 31));
    await tester.pump();
    expect(tappedMark, 'a');

    await tester.tapAt(
      topLeft + Offset(view.cellWidth * 1.5, view.cellHeight - 10),
    );
    await tester.pump();
    expect(tappedDay, DateTime(2026, 11, 17));
  });

  testWidgets('week: uncovered range ensures once and shows loading', (
    tester,
  ) async {
    final date = DateTime(2026, 11, 18);
    final range = streamLevelRangeFor(StreamLevel.week, date);
    final controller = _RecordingController();
    await tester.pumpWidget(
      _hostApp(
        level: StreamLevel.week,
        date: date,
        marks: _marks(const [], covered: false),
        overrides: [
          streamDayCacheControllerProvider.overrideWith(() => controller),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Loading marks'), findsOneWidget);
    expect(find.byType(WeekView), findsNothing);
    expect(controller.calls, [streamLevelQueryRange(range)]);

    await tester.pump();
    expect(controller.calls, hasLength(1));
  });

  testWidgets('month: covered marks render counts and streaks', (tester) async {
    final date = DateTime(2026, 11, 15);
    final streaks = [
      MonthHabitStreak(habitId: 'h1', doneDays: {3, 4}, streakLabel: '2'),
    ];
    DateTime? tapped;
    await tester.pumpWidget(
      _hostApp(
        level: StreamLevel.month,
        date: date,
        firstDayOfWeek: DateTime.sunday,
        habitStreaks: streaks,
        marks: _marks([
          _mark('a', DateTime(2026, 11, 3, 9)),
          _mark('b', DateTime(2026, 11, 3, 11)),
          _mark('c', DateTime(2026, 11, 4, 9)),
          _mark('d', DateTime(2026, 11, 10, 9)),
          _mark('e', DateTime(2026, 11, 10, 10)),
          _mark('f', DateTime(2026, 11, 10, 11)),
        ]),
        onDateTap: (day) => tapped = day,
      ),
    );
    await tester.pump();

    expect(find.byType(MonthView), findsOneWidget);
    final view = tester.widget<MonthView>(find.byType(MonthView));
    expect(view.month, DateTime(2026, 11, 1));
    expect(view.firstDayOfWeek, DateTime.sunday);
    expect(view.habitStreaks, same(streaks));
    expect(view.dayData!.firstWhere((day) => day.date.day == 3).count, 2);
    expect(view.dayData!.firstWhere((day) => day.date.day == 10).count, 3);
    expect(view.dayData!.firstWhere((day) => day.date.day == 10).density, 1.0);

    final topLeft = tester.getTopLeft(find.byType(MonthView));
    final cell = view.cellSize!;
    await tester.tapAt(topLeft + Offset(cell / 2, cell / 2));
    await tester.pump();
    expect(tapped, DateTime(2026, 11, 1));
  });

  testWidgets('month: uncovered range requests ensure once', (tester) async {
    final date = DateTime(2026, 11, 15);
    final range = streamLevelRangeFor(StreamLevel.month, date);
    final calls = <CalendarRange>[];
    await tester.pumpWidget(
      _hostApp(
        level: StreamLevel.month,
        date: date,
        marks: _marks(const [], covered: false),
        ensureRange: (requested) async {
          calls.add(requested);
        },
      ),
    );
    await tester.pump();

    expect(find.text('Loading marks'), findsOneWidget);
    expect(find.byType(MonthView), findsNothing);
    expect(calls, [streamLevelQueryRange(range)]);

    await tester.pump();
    expect(calls, hasLength(1));
  });

  testWidgets('month: covered empty range shows the empty label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _hostApp(
        level: StreamLevel.month,
        date: DateTime(2026, 11, 15),
        marks: _marks(const []),
      ),
    );
    await tester.pump();

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byType(MonthView), findsNothing);
  });

  testWidgets('320dp at 2.0 scale does not overflow', (tester) async {
    await tester.pumpWidget(
      _hostApp(
        level: StreamLevel.week,
        date: DateTime(2026, 11, 18),
        width: 320,
        height: 200,
        textScale: 2.0,
        marks: _marks([
          _mark('a', DateTime(2026, 11, 16, 8)),
          _mark('b', DateTime(2026, 11, 16, 9)),
          _mark('c', DateTime(2026, 11, 16, 10)),
          _mark('d', DateTime(2026, 11, 16, 11)),
          _mark('e', DateTime(2026, 11, 16, 12)),
        ]),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _hostApp(
        level: StreamLevel.month,
        date: DateTime(2026, 11, 15),
        width: 320,
        height: 200,
        textScale: 2.0,
        habitStreaks: [
          MonthHabitStreak(
            habitId: 'h1',
            doneDays: {1, 2, 3},
            streakLabel: '3',
          ),
        ],
        marks: _marks([
          _mark('a', DateTime(2026, 11, 3, 9)),
          _mark('b', DateTime(2026, 11, 10, 9)),
        ]),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
