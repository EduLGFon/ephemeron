// Part of the habits screen library: one row with one-tap logging, skip,
// timer/progress actions, streak, week dots and selection support.
part of '../habits_screen.dart';

enum _HabitAction { edit, activity, add, subtract, skip }

class _HabitTile extends ConsumerWidget {
  const _HabitTile({
    super.key,
    required this.habit,
    required this.selecting,
    required this.selected,
    required this.strings,
    required this.onToggleSelection,
    required this.onStartSelection,
  });

  final Habit habit;
  final bool selecting;
  final bool selected;
  final HabitsStrings strings;
  final VoidCallback onToggleSelection;
  final VoidCallback onStartSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedHabitDayProvider);
    final logsAsync = ref.watch(habitLogsProvider(habit.id));
    final streakAsync = ref.watch(habitStreakProvider(habit.id));
    final storeAsync = ref.watch(habitTimerStoreProvider);
    final currentSession = ref.watch(currentFocusSessionProvider).value;
    return logsAsync.maybeWhen(
      data: (logs) {
        final log = _logFor(logs, day);
        final goal = habit.goalAmount ?? 0;
        final liveSession =
            currentSession != null &&
                goal > 0 &&
                isLiveHabitProgress(
                  habitId: habit.id,
                  selectedDayKey: day,
                  todayKey: habitTodayKey(),
                  unit: habit.unit,
                  sessionHabitId: currentSession.habitId,
                  sessionPhase: currentSession.phase,
                )
            ? currentSession
            : null;
        final streak = streakAsync.value;
        Widget rowFor(double amount) {
          final effectiveLog = amount == (log?.amount ?? 0)
              ? log
              : HabitLog(
                  id: log?.id ?? '',
                  habitId: habit.id,
                  dayKey: day,
                  amount: amount,
                  done: _logDone(habit, log) || (goal > 0 && amount >= goal),
                  skipped: log?.skipped ?? false,
                  createdAt: log?.createdAt ?? 0,
                  updatedAt: log?.updatedAt ?? 0,
                );
          return _buildRow(
            context: context,
            ref: ref,
            logs: logs,
            log: effectiveLog,
            amount: amount,
            streak: streak,
            store: storeAsync.value,
            day: day,
            livePercent: liveSession == null
                ? null
                : formatHabitPercent(amount: amount, goal: goal),
          );
        }

        if (liveSession != null) {
          return _LiveHabitTile(
            session: liveSession,
            habit: habit,
            day: day,
            loggedAmount: log?.amount ?? 0,
            builder: rowFor,
          );
        }
        return rowFor(log?.amount ?? 0);
      },
      orElse: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: DsSpace.x12),
        child: AppSkeleton(height: 32),
      ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required WidgetRef ref,
    required List<HabitLog> logs,
    required HabitLog? log,
    required double amount,
    required ({int current, int best})? streak,
    required HabitTimerStore? store,
    required String day,
    required String? livePercent,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = _logDone(habit, log);
    final skipped = log?.skipped == true;
    final goal = habit.goalAmount ?? 0;
    final hasGoal = goal > 0;
    final progress = _habitProgress(habit, log);
    final category = DsCategoryColors
        .all[habit.id.hashCode.abs() % DsCategoryColors.all.length];
    final timerRunning =
        isMinuteUnit(habit.unit) && store?.active.value?.habitId == habit.id;
    final subtitle = livePercent == null
        ? _habitSubtitle(habit, log, strings)
        : '${strings.progressSemantics} $livePercent';
    final current = streak?.current ?? 0;
    final row = AppHabitRow(
      name: habit.name,
      progress: selecting && selected ? 1 : progress,
      done: selecting ? selected : done,
      color: category.fill(theme.brightness),
      streakLabel: current > 0 ? strings.streak(current) : null,
      weekDots: _habitWeekDots(habit, logs, DateTime.now()),
      subtitle: subtitle,
      onTap: selecting ? onToggleSelection : () => _advanceStep(ref, day),
      onLongPress: onStartSelection,
      trailing: selecting
          ? null
          : _trailing(
              context: context,
              ref: ref,
              day: day,
              skipped: skipped,
              hasGoal: hasGoal,
              amount: amount,
              store: store,
              timerRunning: timerRunning,
            ),
    );
    if (selecting) {
      if (!selected) return row;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(DsRadius.r12),
        ),
        child: row,
      );
    }
    // The shared row exposes one tap for its whole body. Overlay the leading
    // ring with its own target so a body tap advances progress while only the
    // circle marks the day fully done. The 40dp target matches AppHabitRow's
    // ring size and starts at its horizontal padding.
    return Stack(
      children: [
        row,
        Positioned(
          left: DsSpace.x12,
          top: 0,
          bottom: 0,
          width: 40,
          child: Center(
            child: Semantics(
              key: ValueKey<String>('habit-done-${habit.id}'),
              button: true,
              toggled: done,
              label: strings.done,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => _toggleFullyDone(ref, day),
                  onLongPress: onStartSelection,
                  child: const SizedBox(width: 40, height: 40),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _trailing({
    required BuildContext context,
    required WidgetRef ref,
    required String day,
    required bool skipped,
    required bool hasGoal,
    required double amount,
    required HabitTimerStore? store,
    required bool timerRunning,
  }) {
    // A running timer needs the elapsed label plus stop. While it runs the
    // menu and skip stay hidden so the row keeps the week dots at 320dp.
    if (timerRunning && store != null) {
      return _HabitTimerControl(
        habit: habit,
        day: day,
        store: store,
        repo: ref.read(habitRepositoryProvider),
        strings: strings,
        onMessage: (message) {
          if (context.mounted) showAppSnackBar(context, message);
        },
      );
    }
    final hasTimer = isMinuteUnit(habit.unit) && store != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasTimer)
          _HabitTimerControl(
            habit: habit,
            day: day,
            store: store,
            repo: ref.read(habitRepositoryProvider),
            strings: strings,
            onMessage: (message) {
              if (context.mounted) showAppSnackBar(context, message);
            },
          )
        else
          AppIconButton(
            icon: skipped ? Icons.replay : Icons.skip_next_outlined,
            tooltip: skipped ? strings.unskipDay : strings.skipDay,
            semanticLabel: skipped ? strings.unskipDay : strings.skipDay,
            onPressed: () => _toggleSkip(ref, !skipped, day),
          ),
        PopupMenuButton<_HabitAction>(
          tooltip: strings.moreOptions,
          icon: const Icon(Icons.more_vert),
          onSelected: (action) => _onAction(context, ref, action, day),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _HabitAction.edit,
              child: Text(strings.editHabit),
            ),
            PopupMenuItem(
              value: _HabitAction.activity,
              child: Text(strings.viewActivity),
            ),
            PopupMenuItem(
              value: _HabitAction.skip,
              child: Text(skipped ? strings.unskipDay : strings.skipDay),
            ),
            if (hasGoal && amount > 0)
              PopupMenuItem(
                value: _HabitAction.subtract,
                child: Text(strings.subtractStep(_stepLabel(habit))),
              ),
            if (hasGoal)
              PopupMenuItem(
                value: _HabitAction.add,
                child: Text(strings.addStep(_stepLabel(habit))),
              ),
          ],
        ),
      ],
    );
  }

  /// Row tap: one step toward the goal, or a done flip for goal-less habits.
  Future<void> _advanceStep(WidgetRef ref, String day) async {
    AppFeedback.tap();
    await ref
        .read(habitRepositoryProvider)
        .advanceHabit(habit.id, day, habit.increment ?? 1.0);
    ref.invalidate(habitStreakProvider(habit.id));
  }

  /// Leading circle: fully done, using the same toggle API as the Today strip.
  Future<void> _toggleFullyDone(WidgetRef ref, String day) async {
    AppFeedback.selection();
    await ref.read(habitRepositoryProvider).toggleHabitDone(habit.id, day);
    ref.invalidate(habitStreakProvider(habit.id));
  }

  Future<void> _toggleSkip(WidgetRef ref, bool skipped, String day) async {
    AppFeedback.selection();
    await ref.read(habitRepositoryProvider).setSkipped(habit.id, day, skipped);
    ref.invalidate(habitStreakProvider(habit.id));
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _HabitAction action,
    String day,
  ) async {
    switch (action) {
      case _HabitAction.edit:
        await showHabitEditor(context, habit: habit);
      case _HabitAction.skip:
        final current =
            _logFor(
              ref.read(habitLogsProvider(habit.id)).value ?? const [],
              day,
            )?.skipped ??
            false;
        await _toggleSkip(ref, !current, day);
      case _HabitAction.activity:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HabitHeatmapScreen(habitId: habit.id),
          ),
        );
      case _HabitAction.add:
        await ref
            .read(habitRepositoryProvider)
            .addAmount(habit.id, day, habit.increment ?? 1.0);
        ref.invalidate(habitStreakProvider(habit.id));
      case _HabitAction.subtract:
        await ref
            .read(habitRepositoryProvider)
            .subtractAmount(habit.id, day, habit.increment ?? 1.0);
        ref.invalidate(habitStreakProvider(habit.id));
    }
  }
}
