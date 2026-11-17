// Hosts the Stream Week and Month semantic-zoom levels.
//
// Presentation/application only: computes the local level range, waits for the
// occurrence cache to cover it through StreamDayCacheController.ensure, groups
// the marks with LevelData and renders the existing WeekView/MonthView. The
// caller supplies every user-visible label and callback, so the host adds no
// route, nested scrollable or English copy. See ARCHITECTURE.md.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../calendar/application/calendar_state.dart' show CalendarRange;
import '../../application/stream_day_cache.dart';
import '../../application/stream_day_mark.dart';
import '../../application/stream_level_data.dart';
import '../levels/level_data.dart';
import '../levels/month_view.dart';
import '../levels/week_view.dart';

/// Renders one Week or Month level for [date] inside the available space.
///
/// [firstDayOfWeek] configures the MonthView grid. The week range follows
/// [streamLevelRangeFor], which uses a Monday-first local week.
class StreamLevelHost extends ConsumerStatefulWidget {
  const StreamLevelHost({
    super.key,
    required this.level,
    required this.date,
    this.firstDayOfWeek = DateTime.monday,
    required this.dayHeaderBuilder,
    required this.daySemanticsLabel,
    required this.monthDaySemanticsLabel,
    required this.streakSemanticsLabel,
    required this.markSemanticsLabel,
    required this.markActionLabels,
    required this.emptyLabel,
    required this.loadingLabel,
    required this.errorLabel,
    this.onDayTap,
    this.onMarkTap,
    this.onDateTap,
    this.onHabitTap,
    this.habitStreaks,
    this.ensureRange,
  }) : assert(level != StreamLevel.day, 'Week or month level expected');

  final StreamLevel level;
  final DateTime date;
  final int firstDayOfWeek;

  /// Caller-localized header for one week day.
  final String Function(int dayIndex, DateTime date) dayHeaderBuilder;

  /// Caller-localized semantics label for one week day.
  final String Function(int dayIndex, DateTime date) daySemanticsLabel;

  /// Caller-localized semantics label for one month day and its mark count.
  final String Function(int day, int count) monthDaySemanticsLabel;

  /// Caller-localized semantics label for a habit streak segment.
  final String Function(MonthHabitStreak streak, int firstDay, int lastDay)
  streakSemanticsLabel;

  /// Caller-localized semantics label for one mark.
  final String Function(StreamDayMark mark) markSemanticsLabel;

  /// Caller-localized labels for the mark custom actions.
  final Map<String, String> markActionLabels;

  final String emptyLabel;
  final String loadingLabel;
  final String errorLabel;

  final void Function(DateTime date)? onDayTap;
  final void Function(String markId)? onMarkTap;
  final void Function(DateTime date)? onDateTap;
  final void Function(String habitId)? onHabitTap;
  final List<MonthHabitStreak>? habitStreaks;

  /// Overrides the cache controller; useful for hosts without a repository.
  final void Function(CalendarRange range)? ensureRange;

  @override
  ConsumerState<StreamLevelHost> createState() => _StreamLevelHostState();
}

class _StreamLevelHostState extends ConsumerState<StreamLevelHost> {
  StreamLevelRange? _ensuredRange;

  @override
  Widget build(BuildContext context) {
    final range = streamLevelRangeFor(widget.level, widget.date);
    final marksAsync = ref.watch(streamLevelMarksProvider(range));
    final cacheStatus = widget.ensureRange == null
        ? ref.watch(streamDayCacheControllerProvider)
        : StreamDayCacheStatus.idle;
    return marksAsync.when(
      loading: () => _message(widget.loadingLabel),
      error: (error, stackTrace) => _message(widget.errorLabel),
      data: (data) {
        if (!data.covered) {
          _scheduleEnsure(range);
          return _message(
            cacheStatus == StreamDayCacheStatus.error
                ? widget.errorLabel
                : widget.loadingLabel,
          );
        }
        if (data.marks.isEmpty) return _message(widget.emptyLabel);
        return widget.level == StreamLevel.week
            ? _buildWeek(range, data.marks)
            : _buildMonth(range, data.marks);
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

  Widget _buildWeek(StreamLevelRange range, List<StreamDayMark> marks) {
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
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 280.0;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 240.0;
        return WeekView(
          weekStart: range.start,
          dayMarks: dayMarks,
          cellWidth: width / 7,
          cellHeight: height,
          dayHeaderBuilder: widget.dayHeaderBuilder,
          daySemanticsLabel: (index, [date]) =>
              widget.daySemanticsLabel(index, date ?? range.start),
          markSemanticsLabel: widget.markSemanticsLabel,
          markActionLabels: widget.markActionLabels,
          onDayTap: widget.onDayTap,
          onMarkTap: widget.onMarkTap,
        );
      },
    );
  }

  Widget _buildMonth(StreamLevelRange range, List<StreamDayMark> marks) {
    final lastDay = DateTime(
      range.end.year,
      range.end.month,
      range.end.day - 1,
    );
    final dayData =
        LevelData.countsForRange(
              rangeStart: range.start,
              rangeEnd: lastDay,
              marks: marks,
            )
            .map(
              (count) => MonthDayData(
                date: count.day,
                count: count.count,
                density: count.density,
              ),
            )
            .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 280.0;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 320.0;
        final rows = _monthRows(range.start, widget.firstDayOfWeek);
        final cellSize = math.max(1.0, math.min(width / 7, height / rows));
        return Center(
          child: MonthView(
            month: range.start,
            dayData: dayData,
            cellSize: cellSize,
            firstDayOfWeek: widget.firstDayOfWeek,
            habitStreaks: widget.habitStreaks,
            daySemanticsLabel: widget.monthDaySemanticsLabel,
            streakSemanticsLabel: widget.streakSemanticsLabel,
            onDateTap: widget.onDateTap,
            onHabitTap: widget.onHabitTap,
          ),
        );
      },
    );
  }

  static int _monthRows(DateTime month, int firstDayOfWeek) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = (first.weekday - firstDayOfWeek + 7) % 7;
    return ((offset + days) / 7).ceil();
  }

  Widget _message(String label) {
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
}
