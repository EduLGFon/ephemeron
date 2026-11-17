part of 'stream_level_host.dart';

Widget _weekLevelBody({
  required StreamLevelHost host,
  required StreamLevelRange range,
  required List<StreamDayMark> marks,
}) {
  final grouped = LevelData.groupByLocalDay(marks);
  final dayMarks = List<List<StreamDayMark>>.generate(7, (index) {
    final day = DateTime(
      range.start.year,
      range.start.month,
      range.start.day + index,
    );
    return grouped[day] ?? const <StreamDayMark>[];
  }, growable: false);
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = _boundedWidth(constraints);
      final height = _boundedHeight(constraints, 240);
      return WeekView(
        weekStart: range.start,
        dayMarks: dayMarks,
        cellWidth: width / 7,
        cellHeight: height,
        dayHeaderBuilder: host.dayHeaderBuilder,
        daySemanticsLabel: (index, [date]) =>
            host.daySemanticsLabel(index, date ?? range.start),
        markSemanticsLabel: host.markSemanticsLabel,
        markActionLabels: host.markActionLabels,
        onDayTap: host.onDayTap,
        onMarkTap: host.onMarkTap,
      );
    },
  );
}

Widget _monthLevelBody({
  required StreamLevelHost host,
  required StreamLevelRange range,
  required List<StreamDayMark> marks,
}) {
  final dayData = _monthDayData(range, marks);
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = _boundedWidth(constraints);
      final height = _boundedHeight(constraints, 320);
      final rows = _monthRows(range.start, host.firstDayOfWeek);
      final cellSize = math.max(1.0, math.min(width / 7, height / rows));
      return Center(
        child: MonthView(
          month: range.start,
          dayData: dayData,
          cellSize: cellSize,
          firstDayOfWeek: host.firstDayOfWeek,
          habitStreaks: host.habitStreaks,
          daySemanticsLabel: host.monthDaySemanticsLabel,
          streakSemanticsLabel: host.streakSemanticsLabel,
          onDateTap: host.onDateTap,
          onHabitTap: host.onHabitTap,
        ),
      );
    },
  );
}

List<MonthDayData> _monthDayData(
  StreamLevelRange range,
  List<StreamDayMark> marks,
) {
  final lastDay = DateTime(range.end.year, range.end.month, range.end.day - 1);
  return LevelData.countsForRange(
        rangeStart: range.start,
        rangeEnd: lastDay,
        marks: marks,
      )
      .map((count) {
        return MonthDayData(
          date: count.day,
          count: count.count,
          density: count.density,
        );
      })
      .toList(growable: false);
}

int _monthRows(DateTime month, int firstDayOfWeek) {
  final first = DateTime(month.year, month.month, 1);
  final days = DateTime(month.year, month.month + 1, 0).day;
  final offset = (first.weekday - firstDayOfWeek + 7) % 7;
  return ((offset + days) / 7).ceil();
}

double _boundedWidth(BoxConstraints constraints) =>
    constraints.hasBoundedWidth ? constraints.maxWidth : 280.0;

double _boundedHeight(BoxConstraints constraints, double fallback) =>
    constraints.hasBoundedHeight ? constraints.maxHeight : fallback;

Widget _message(BuildContext context, String label) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
