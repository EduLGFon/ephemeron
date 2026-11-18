// Hosts the Stream Week, Month and Year semantic-zoom levels plus the agenda
// lens over any level range.
//
// Presentation/application only: computes the local level range, waits for the
// occurrence cache to cover it through StreamDayCacheController.ensure, groups
// the marks with LevelData and renders the existing WeekView/MonthView/YearView.
// The caller supplies every user-visible label and callback, so the host adds
// no route, nested scrollable or English copy. See ARCHITECTURE.md.
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
import '../levels/year_view.dart';
import 'stream_agenda_host.dart';

part 'stream_level_host_views.dart';

/// Renders one Week, Month or Year level for [date] inside the available space.
///
/// The week starts on [firstDayOfWeek]; the month and year grids use the same
/// value.
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
    this.yearHabitStreaks,
    this.yearMonthHeading,
    this.yearMonthSemanticsLabel,
    this.yearDaySemanticsLabel,
    this.yearHabitStreakSemanticsLabel,
    this.ensureRange,
  }) : assert(level != StreamLevel.day, 'Week, month or year level expected'),
       assert(
         level != StreamLevel.year ||
             (yearMonthHeading != null &&
                 yearMonthSemanticsLabel != null &&
                 yearDaySemanticsLabel != null &&
                 yearHabitStreakSemanticsLabel != null),
         'Year labels are required for the year level',
       );

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
  final List<YearHabitStreak>? yearHabitStreaks;

  /// Caller-localized heading for one year month (1-12).
  final String Function(int month)? yearMonthHeading;

  /// Caller-localized semantics label for one year month and its count.
  final String Function(String heading, int count)? yearMonthSemanticsLabel;

  /// Caller-localized semantics label for one year day and its mark count.
  final String Function(DateTime date, int count)? yearDaySemanticsLabel;

  /// Caller-localized semantics label for one year habit streak run.
  final String Function(YearHabitStreak streak, DateTime first, DateTime last)?
  yearHabitStreakSemanticsLabel;

  /// Overrides the cache controller; useful for hosts without a repository.
  final void Function(CalendarRange range)? ensureRange;

  @override
  ConsumerState<StreamLevelHost> createState() => _StreamLevelHostState();
}

class _StreamLevelHostState extends ConsumerState<StreamLevelHost> {
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
        if (data.marks.isEmpty) {
          return _message(context, widget.emptyLabel);
        }
        return switch (widget.level) {
          StreamLevel.week => _weekLevelBody(
            host: widget,
            range: range,
            marks: data.marks,
          ),
          StreamLevel.month => _monthLevelBody(
            host: widget,
            range: range,
            marks: data.marks,
          ),
          StreamLevel.year => _yearLevelBody(
            host: widget,
            range: range,
            marks: data.marks,
          ),
          // The constructor asserts the day level away; keep the switch total.
          StreamLevel.day => _message(context, widget.emptyLabel),
        };
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
