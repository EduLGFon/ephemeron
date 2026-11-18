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

Widget _yearLevelBody({
  required StreamLevelHost host,
  required StreamLevelRange range,
  required List<StreamDayMark> marks,
}) {
  final lastDay = DateTime(range.end.year, range.end.month, range.end.day - 1);
  final counts = LevelData.countsForRange(
    rangeStart: range.start,
    rangeEnd: lastDay,
    marks: marks,
  );
  final dayCounts = <String, int>{
    for (final count in counts) yearDayKey(count.day): count.count,
  };
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = _boundedWidth(constraints);
      // YearView paints a fixed-size canvas for the whole year. FittedBox
      // keeps all twelve months visible in the available body height without
      // adding a nested scrollable; hit testing follows the scale.
      return Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: width,
            child: YearView(
              year: range.start.year,
              dayCounts: dayCounts,
              habitStreaks: host.yearHabitStreaks ?? const <YearHabitStreak>[],
              firstDayOfWeek: host.firstDayOfWeek,
              monthHeading: host.yearMonthHeading!,
              monthSemanticsLabel: host.yearMonthSemanticsLabel!,
              daySemanticsLabel: host.yearDaySemanticsLabel!,
              habitStreakSemanticsLabel: host.yearHabitStreakSemanticsLabel!,
              onDateTap: host.onDateTap,
              onHabitTap: host.onHabitTap,
            ),
          ),
        ),
      );
    },
  );
}

/// Agenda lens over one level range.
///
/// Uses the same [streamLevelMarksProvider] range as the level hosts, so the
/// toggle never introduces a second data source or a write path. Day is
/// accepted here: the agenda is a lens over the day range, not a zoom level.
class StreamLevelAgenda extends ConsumerStatefulWidget {
  const StreamLevelAgenda({
    super.key,
    required this.level,
    required this.date,
    this.firstDayOfWeek = DateTime.monday,
    required this.emptyLabel,
    required this.loadingLabel,
    required this.errorLabel,
    required this.formatTime,
    required this.markSemanticsLabel,
    required this.dayHeadingBuilder,
    required this.onMarkTap,
    this.ensureRange,
  });

  final StreamLevel level;
  final DateTime date;
  final int firstDayOfWeek;
  final String emptyLabel;
  final String loadingLabel;
  final String errorLabel;
  final String Function(int startMs) formatTime;
  final String Function(StreamDayMark mark) markSemanticsLabel;
  final String Function(DateTime day) dayHeadingBuilder;
  final void Function(StreamDayMark mark) onMarkTap;

  /// Overrides the cache controller; useful for hosts without a repository.
  final void Function(CalendarRange range)? ensureRange;

  @override
  ConsumerState<StreamLevelAgenda> createState() => _StreamLevelAgendaState();
}

class _StreamLevelAgendaState extends ConsumerState<StreamLevelAgenda> {
  StreamLevelRange? _ensuredRange;

  @override
  Widget build(BuildContext context) {
    final range = streamLevelRangeFor(
      widget.level,
      widget.date,
      firstDayOfWeek: widget.firstDayOfWeek,
    );
    final marksAsync = ref.watch(streamLevelMarksProvider(range));
    final cacheStatus = widget.ensureRange == null
        ? ref.watch(streamDayCacheControllerProvider)
        : StreamDayCacheStatus.idle;
    return marksAsync.when(
      loading: () => _message(context, widget.loadingLabel),
      error: (error, stackTrace) => _message(context, widget.errorLabel),
      data: (data) {
        if (!data.covered) {
          _scheduleEnsure(range);
          return _message(
            context,
            cacheStatus == StreamDayCacheStatus.error
                ? widget.errorLabel
                : widget.loadingLabel,
          );
        }
        return StreamAgendaHost(
          marks: data.marks,
          emptyLabel: widget.emptyLabel,
          formatTime: widget.formatTime,
          semanticLabel: widget.markSemanticsLabel,
          dayHeadingBuilder: widget.dayHeadingBuilder,
          onMarkTap: (id) {
            for (final mark in data.marks) {
              if (mark.id != id) continue;
              widget.onMarkTap(mark);
              return;
            }
          },
        );
      },
    );
  }

  void _scheduleEnsure(StreamLevelRange range) {
    if (_ensuredRange == range) return;
    _ensuredRange = range;
    final query = streamLevelQueryRange(range);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ensureRange = widget.ensureRange;
      if (ensureRange != null) {
        ensureRange(query);
        return;
      }
      unawaited(
        ref.read(streamDayCacheControllerProvider.notifier).ensure(query),
      );
    });
  }
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
