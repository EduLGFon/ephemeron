// Read models for the Today home. Every list is derived from one range or
// one stream emission so rows never fan out into per-row database queries.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time.dart';
import '../../../data/drift/app_database.dart';
import '../../calendar/application/calendar_cache_coordinator.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/application/calendar_state.dart';
import '../../countdowns/application/countdowns_providers.dart';
import '../../countdowns/presentation/countdown_formatters.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../../domain/habits/habit_calendar_entry.dart';

/// Injectable wall clock. Tests override this to freeze "today".
final deviceNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Local `YYYY-MM-DD` key for the current day.
final todayKeyProvider = Provider<String>((ref) {
  return dateKey(ref.watch(deviceNowProvider)().toLocal());
});

/// Local midnight to the next local midnight, in the UTC half-open form the
/// occurrence cache uses.
final todayRangeProvider = Provider<CalendarRange>((ref) {
  final now = ref.watch(deviceNowProvider)().toLocal();
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day + 1);
  return CalendarRange(fromUtc: start.toUtc(), toUtc: end.toUtc());
});

/// Today and overdue open tasks in display order.
class TodayTaskBuckets {
  const TodayTaskBuckets({required this.today, required this.overdue});

  final List<Task> today;
  final List<Task> overdue;

  bool get isEmpty => today.isEmpty && overdue.isEmpty;
  int get total => today.length + overdue.length;
}

bool isTaskToday(Task task, String todayKey) {
  return task.dueDate == todayKey || task.plannedDate == todayKey;
}

bool isTaskOverdue(Task task, String todayKey) {
  final dueOverdue =
      task.dueDate != null && task.dueDate!.compareTo(todayKey) < 0;
  final plannedOverdue =
      task.plannedDate != null && task.plannedDate!.compareTo(todayKey) < 0;
  return dueOverdue || plannedOverdue;
}

/// Local minute of day for sorting: planned start, then due time, else end of
/// day. Invalid planned starts fall through to the due time.
int taskMinuteOfDay(Task task) {
  final planned = task.plannedStart;
  if (planned != null && planned.length >= 16) {
    final hour = int.tryParse(planned.substring(11, 13));
    final minute = int.tryParse(planned.substring(14, 16));
    if (hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59) {
      return hour * 60 + minute;
    }
  }
  return task.dueTime ?? 24 * 60;
}

int _compareTasks(Task a, Task b) {
  final byTime = taskMinuteOfDay(a).compareTo(taskMinuteOfDay(b));
  if (byTime != 0) return byTime;
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (byTitle != 0) return byTitle;
  return a.id.compareTo(b.id);
}

/// Splits open tasks once per stream emission. A task with any date today is
/// in `today`; otherwise a past due/planned date makes it overdue. No task
/// appears in both buckets.
TodayTaskBuckets bucketTodayTasks(List<Task> tasks, String todayKey) {
  final today = <Task>[];
  final overdue = <Task>[];
  for (final task in tasks) {
    if (isTaskToday(task, todayKey)) {
      today.add(task);
    } else if (isTaskOverdue(task, todayKey)) {
      overdue.add(task);
    }
  }
  today.sort(_compareTasks);
  overdue.sort(_compareTasks);
  return TodayTaskBuckets(today: today, overdue: overdue);
}

final todayTasksProvider = Provider<AsyncValue<TodayTaskBuckets>>((ref) {
  final today = ref.watch(todayKeyProvider);
  return ref
      .watch(openTasksProvider(null))
      .whenData((tasks) => bucketTodayTasks(tasks, today));
});

/// Today's event occurrences: task projections are excluded because the task
/// list carries full [Task] rows for checkboxes.
final todayOccurrencesProvider = Provider<AsyncValue<List<OccurrenceCacheData>>>(
  (ref) {
    final range = ref.watch(todayRangeProvider);
    ref.listen<bool>(occurrenceDirtyProvider, (previous, dirty) {
      // External writes may delete rows the coordinator still counts as built.
      if (dirty) ref.invalidate(calendarCacheCoordinatorProvider);
    });
    if (ref.read(occurrenceDirtyProvider)) {
      // Invalidate outside the provider build; the watch below subscribes to
      // the fresh coordinator and re-ensures the range.
      Future.microtask(() => ref.invalidate(calendarCacheCoordinatorProvider));
    }
    return ref
        .watch(calendarRangeOccurrencesProvider(range))
        .whenData(
          (rows) => rows
              .where((row) => row.sourceType != 'task')
              .toList(growable: false),
        );
  },
);

/// Today's scheduled habits with their log amount/done/skipped state.
final todayHabitEntriesProvider =
    Provider<AsyncValue<List<HabitCalendarEntry>>>((ref) {
      final today = ref.watch(todayKeyProvider);
      final range = ref.watch(todayRangeProvider);
      return ref
          .watch(calendarHabitEntriesProvider(range))
          .whenData(
            (entries) => entries
                .where((entry) => entry.dayKey == today)
                .toList(growable: false),
          );
    });

/// Upcoming countdowns with resolved day distance, nearest first.
class TodayCountdown {
  const TodayCountdown({
    required this.countdown,
    required this.next,
    required this.days,
  });

  final Countdown countdown;
  final DateTime next;
  final int days;
}

final todayCountdownsProvider = Provider<AsyncValue<List<TodayCountdown>>>((
  ref,
) {
  final now = ref.watch(deviceNowProvider)();
  return ref.watch(countdownsProvider).whenData((countdowns) {
    final items = <TodayCountdown>[];
    for (final countdown in countdowns) {
      final schedule = countdownSchedule(
        targetDate: countdown.targetDate,
        yearlyRepeat: countdown.yearlyRepeat,
        today: now,
      );
      if (schedule == null) continue;
      items.add(
        TodayCountdown(
          countdown: countdown,
          next: schedule.next,
          days: schedule.days,
        ),
      );
    }
    items.sort((a, b) {
      final byDays = a.days.compareTo(b.days);
      if (byDays != 0) return byDays;
      return a.countdown.title.toLowerCase().compareTo(
        b.countdown.title.toLowerCase(),
      );
    });
    return items;
  });
});

/// Resolves today's visual priority for [AppTaskRow]: persisted 4=P1 maps to
/// visual 1, 1=P4 maps to visual 4, and unprioritized stays 0.
int visualTaskPriority(Task task) => task.priority == 0 ? 0 : 5 - task.priority;
