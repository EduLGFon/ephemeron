// Today home: the calm default surface. Local data renders immediately; no
// spinner is shown for Drift-backed content, and no row performs its own
// database query.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/destinations.dart';
import '../../../core/design/components/app_page.dart';
import '../../../core/design/components/app_states.dart' hide AppSkeleton;
import '../../../core/design/components/sync_indicator.dart';
import '../../../core/design/layout.dart';
import '../../../core/design/tokens.dart';
import '../../../core/ui/app_feedback.dart';
import '../../../core/ui/app_skeleton.dart';
import '../../../data/drift/app_database.dart';
import '../../../features/calendar/application/calendar_cache_coordinator.dart';
import '../../../features/calendar/presentation/event_details_sheet.dart';
import '../../../features/calendar/presentation/task_action_sheet.dart';
import '../../../features/habits/application/habits_providers.dart';
import '../../../features/sync/application/sync_providers.dart';
import '../../../features/sync/data/sync_engine.dart';
import '../../../features/tasks/application/tasks_providers.dart';
import '../../../features/tasks/presentation/quick_add_sheet.dart';
import '../../../domain/habits/habit_calendar_entry.dart';
import '../application/today_providers.dart';
import 'today_strings.dart';
import 'widgets/today_agenda.dart';
import 'widgets/today_countdowns.dart';
import 'widgets/today_habits.dart';
import 'widgets/today_header.dart';
import 'widgets/today_hero.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, this.now});

  /// Fixed wall clock for tests and deterministic previews.
  final DateTime? now;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final ValueNotifier<DateTime> _minuteTick;
  Timer? _minuteTimer;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _minuteTick = ValueNotifier<DateTime>(_now);
    _alignMinuteClock();
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _minuteTick.dispose();
    super.dispose();
  }

  void _alignMinuteClock() {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    _minuteTimer = Timer(nextMinute.difference(now), () {
      _minuteTick.value = DateTime.now();
      // One periodic timer drives the rest of the screen's relative labels.
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _minuteTick.value = DateTime.now();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = TodayStrings.of(context);
    final layout = AppLayoutScope.maybeOf(context) ?? AppLayout.compact;
    final occurrences = ref.watch(todayOccurrencesProvider);
    final tasks = ref.watch(todayTasksProvider);
    final habits = ref.watch(todayHabitEntriesProvider);
    final countdowns = ref.watch(todayCountdownsProvider);
    final taskLists = ref.watch(taskListsByIdProvider);
    final now = _now;

    final hasError = occurrences.hasError || tasks.hasError || habits.hasError;
    // Keep the first frame stable: async defaults must not flash the empty
    // state or swap the hero before core data resolves.
    final initialLoading =
        (occurrences.isLoading && !occurrences.hasValue) ||
        (tasks.isLoading && !tasks.hasValue) ||
        (habits.isLoading && !habits.hasValue) ||
        (countdowns.isLoading && !countdowns.hasValue);

    final events = occurrences.value ?? const <OccurrenceCacheData>[];
    final buckets =
        tasks.value ??
        const TodayTaskBuckets(today: <Task>[], overdue: <Task>[]);
    final habitEntries = habits.value ?? const [];
    final countdownItems = countdowns.value ?? const <TodayCountdown>[];
    final current = _currentEvent(events, now);
    final next = current == null ? _nextEvent(events, now) : null;

    return AppPage(
      header: TodayHeader(
        now: now,
        syncState: _syncState(ref.watch(combinedSyncStatusProvider)),
        onSettings: () => _open('/settings'),
        onSearch: () => _open('/search'),
        onOpenDestination: (branch) =>
            _open(AppDestination.pathForBranch(branch)),
      ),
      child: hasError
          ? AppErrorState(
              title: strings.couldNotLoad,
              onRetry: () {
                ref.invalidate(calendarCacheCoordinatorProvider);
                ref.invalidate(
                  calendarRangeOccurrencesProvider(
                    ref.read(todayRangeProvider),
                  ),
                );
                ref.invalidate(openTasksProvider(null));
              },
            )
          : initialLoading
          ? _loadingBody(layout)
          : SingleChildScrollView(
              key: ValueKey<String>(
                layout == AppLayout.expanded
                    ? 'today-wide-body'
                    : 'today-compact-body',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TodayHero(
                    now: now,
                    minuteTick: _minuteTick,
                    currentEvent: current,
                    nextEvent: next,
                    onOpenEvent: _openEvent,
                    onOpenFocus: () => _open(AppDestination.focus.path),
                  ),
                  const SizedBox(height: DsSpace.x16),
                  if (layout == AppLayout.expanded)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: _agendaOrEmpty(
                            strings,
                            events,
                            buckets,
                            taskLists,
                            now,
                            habitEntries.isEmpty,
                          ),
                        ),
                        const SizedBox(width: DsSpace.x24),
                        SizedBox(
                          width: 300,
                          child: _sideColumn(
                            habitEntries,
                            countdownItems,
                            expanded: true,
                          ),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    _sideColumn(habitEntries, countdownItems, expanded: false),
                    if (habitEntries.isNotEmpty || countdownItems.isNotEmpty)
                      const SizedBox(height: DsSpace.x16),
                    _agendaOrEmpty(
                      strings,
                      events,
                      buckets,
                      taskLists,
                      now,
                      habitEntries.isEmpty,
                    ),
                  ],
                  const SizedBox(height: DsSpace.x48),
                ],
              ),
            ),
    );
  }

  Widget _loadingBody(AppLayout layout) {
    final hero = AppSkeleton.box(height: 112);
    final agenda = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSkeleton.box(height: 20, width: 120),
        const SizedBox(height: DsSpace.x12),
        AppSkeleton.box(height: 56),
        const SizedBox(height: DsSpace.x8),
        AppSkeleton.box(height: 56),
        const SizedBox(height: DsSpace.x8),
        AppSkeleton.box(height: 56),
      ],
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSkeleton.box(height: 20, width: 100),
        const SizedBox(height: DsSpace.x12),
        AppSkeleton.box(height: 96),
      ],
    );
    return SingleChildScrollView(
      key: ValueKey<String>(
        layout == AppLayout.expanded ? 'today-wide-body' : 'today-compact-body',
      ),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          hero,
          const SizedBox(height: DsSpace.x16),
          if (layout == AppLayout.expanded)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 3, child: agenda),
                const SizedBox(width: DsSpace.x24),
                SizedBox(width: 300, child: side),
              ],
            )
          else ...<Widget>[side, const SizedBox(height: DsSpace.x16), agenda],
          const SizedBox(height: DsSpace.x48),
        ],
      ),
    );
  }

  Widget _agendaOrEmpty(
    TodayStrings strings,
    List<OccurrenceCacheData> events,
    TodayTaskBuckets tasks,
    Map<String, TaskList> taskLists,
    DateTime now,
    bool habitsEmpty,
  ) {
    if (events.isEmpty && tasks.isEmpty && habitsEmpty) {
      return AppEmptyState(
        key: const ValueKey<String>('today-empty'),
        icon: Icons.wb_sunny_outlined,
        title: strings.emptyTitle,
        message: strings.emptyMessage,
        actionLabel: strings.addSomething,
        onAction: () => showQuickAdd(context),
      );
    }
    return TodayAgenda(
      events: events,
      tasks: tasks,
      taskLists: taskLists,
      todayDate: now,
      onEventTap: _openEvent,
      onTaskTap: _openTask,
      onToggleTask: _completeTask,
    );
  }

  Widget _sideColumn(
    List<HabitCalendarEntry> habitEntries,
    List<TodayCountdown> countdowns, {
    required bool expanded,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TodayHabits(
          entries: habitEntries,
          expanded: expanded,
          onAdvance: _advanceHabit,
          onDone: _toggleHabitDone,
        ),
        if (habitEntries.isNotEmpty && countdowns.isNotEmpty)
          const SizedBox(height: DsSpace.x16),
        TodayCountdowns(
          items: countdowns,
          onSeeAll: () => _open(AppDestination.countdowns.path),
        ),
      ],
    );
  }

  OccurrenceCacheData? _currentEvent(
    List<OccurrenceCacheData> events,
    DateTime now,
  ) {
    final nowMs = now.millisecondsSinceEpoch;
    for (final event in events) {
      if (event.endUtc - event.startUtc >= Duration.millisecondsPerDay) {
        continue;
      }
      if (event.startUtc <= nowMs && event.endUtc > nowMs) return event;
    }
    return null;
  }

  OccurrenceCacheData? _nextEvent(
    List<OccurrenceCacheData> events,
    DateTime now,
  ) {
    final nowMs = now.millisecondsSinceEpoch;
    OccurrenceCacheData? best;
    for (final event in events) {
      if (event.endUtc - event.startUtc >= Duration.millisecondsPerDay) {
        continue;
      }
      if (event.startUtc <= nowMs) continue;
      if (best == null || event.startUtc < best.startUtc) best = event;
    }
    return best;
  }

  AppSyncState _syncState(SyncStatus status) {
    return switch (status) {
      SyncStatus.synced => AppSyncState.synced,
      SyncStatus.syncing => AppSyncState.syncing,
      SyncStatus.offline => AppSyncState.offline,
      SyncStatus.error => AppSyncState.attention,
    };
  }

  void _open(String path) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (path == '/settings' || path == '/search' || path == '/alarm-settings') {
      router.push(path);
    } else {
      // Branch destinations belong to the shell's indexed stack.
      router.go(path);
    }
  }

  Future<void> _openEvent(OccurrenceCacheData event) async {
    await showEventDetails(
      context,
      event.eventId,
      occurrenceStartMs: event.startUtc,
    );
  }

  Future<void> _openTask(Task task) async {
    await showTaskActionSheet(
      context,
      taskId: task.id,
      occurrenceDate: ref.read(todayKeyProvider),
    );
  }

  Future<void> _completeTask(Task task) async {
    final strings = TodayStrings.of(context);
    try {
      await ref.read(taskRepositoryProvider).completeTask(task.id);
      AppFeedback.success();
      ref.read(occurrenceDirtyProvider.notifier).markDirty();
      if (!mounted) return;
      showUndoSnackBar(
        context,
        strings.taskCompleted,
        onUndo: () {
          ref.read(taskRepositoryProvider).uncompleteTask(task.id);
          ref.read(occurrenceDirtyProvider.notifier).markDirty();
        },
      );
    } catch (_) {
      if (mounted) showErrorSnackBar(context, strings.couldNotComplete);
    }
  }

  /// Chip body tap: advance by the habit's configured increment (default 1).
  /// Goal-less habits flip done through advanceHabit.
  Future<void> _advanceHabit(HabitCalendarEntry entry) async {
    final strings = TodayStrings.of(context);
    try {
      AppFeedback.tap();
      await ref
          .read(habitRepositoryProvider)
          .advanceHabit(entry.habitId, habitTodayKey(), entry.increment ?? 1.0);
      ref.invalidate(habitStreakProvider(entry.habitId));
    } catch (_) {
      if (mounted) showErrorSnackBar(context, strings.couldNotUpdateHabit);
    }
  }

  /// Leading circle tap: mark the day fully done, mirroring the habits screen.
  Future<void> _toggleHabitDone(HabitCalendarEntry entry) async {
    final strings = TodayStrings.of(context);
    try {
      AppFeedback.success();
      await ref
          .read(habitRepositoryProvider)
          .toggleHabitDone(entry.habitId, habitTodayKey());
      ref.invalidate(habitStreakProvider(entry.habitId));
    } catch (_) {
      if (mounted) showErrorSnackBar(context, strings.couldNotUpdateHabit);
    }
  }
}
