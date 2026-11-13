// Part of the habits screen library: one habit row with one-tap logging,
// decrement, skip, timer/progress actions, and selection support.
part of '../habits_screen.dart';

HabitLog? _logFor(List<HabitLog> logs, String day) {
  for (final l in logs) {
    if (l.dayKey == day) return l;
  }
  return null;
}

/// Icon-only row actions keep their 20 dp glyph but reserve a 48 dp target so
/// they meet the accessibility minimum at narrow widths and large text.
ButtonStyle _habitActionStyle() => IconButton.styleFrom(
  fixedSize: const Size.square(48),
  padding: EdgeInsets.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

class _HabitTile extends ConsumerWidget {
  const _HabitTile({
    required this.habit,
    required this.selecting,
    required this.selected,
    required this.onToggleSelection,
    required this.onStartSelection,
  });

  final Habit habit;
  final bool selecting;
  final bool selected;
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
        final done = log?.done ?? false;
        final skipped = log?.skipped ?? false;
        final amount = log?.amount ?? 0.0;
        final goal = habit.goalAmount ?? 0.0;
        final hasGoal = goal > 0;
        final step = habit.increment ?? 1.0;
        final repo = ref.read(habitRepositoryProvider);
        final liveSession =
            currentSession != null &&
                hasGoal &&
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
        return ListTile(
          selected: selected,
          leading: Checkbox(
            value: selecting ? selected : done,
            onChanged: (_) {
              if (selecting) {
                AppFeedback.selection();
                onToggleSelection();
                return;
              }
              AppFeedback.tap();
              _toggleDone(context, ref, !done);
            },
          ),
          title: Text(
            habit.name,
            style: done
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: _subtitle(
            context,
            day: day,
            streak: streakAsync.value,
            skipped: skipped,
            amount: amount,
            goal: goal,
            hasGoal: hasGoal,
            liveSession: liveSession,
          ),
          trailing: selecting
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasGoal && amount > 0)
                      IconButton(
                        style: _habitActionStyle(),
                        iconSize: 20,
                        icon: const Icon(Icons.remove),
                        tooltip: 'Subtract ${_fmt(step)}',
                        onPressed: () async {
                          AppFeedback.tap();
                          await repo.subtractAmount(habit.id, day, step);
                          ref.invalidate(habitStreakProvider(habit.id));
                        },
                      ),
                    if (hasGoal)
                      IconButton(
                        style: _habitActionStyle(),
                        iconSize: 20,
                        icon: const Icon(Icons.add),
                        tooltip: 'Add ${_fmt(step)}',
                        onPressed: () async {
                          AppFeedback.tap();
                          await repo.addAmount(habit.id, day, step);
                          ref.invalidate(habitStreakProvider(habit.id));
                        },
                      ),
                    if (isMinuteUnit(habit.unit) && storeAsync.hasValue)
                      _HabitTimerControl(
                        habit: habit,
                        day: day,
                        store: storeAsync.value!,
                        repo: repo,
                        onMessage: (m) {
                          if (context.mounted) {
                            showAppSnackBar(context, m);
                          }
                        },
                      ),
                    IconButton(
                      style: _habitActionStyle(),
                      iconSize: 20,
                      icon: Icon(
                        skipped
                            ? Icons.play_arrow_outlined
                            : Icons.pause_outlined,
                      ),
                      tooltip: skipped ? 'Unskip' : 'Skip day',
                      color: skipped
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      onPressed: () {
                        AppFeedback.selection();
                        _toggleSkip(context, ref, !skipped);
                      },
                    ),
                  ],
                ),
          onTap: selecting
              ? onToggleSelection
              : () => showHabitEditor(context, habit: habit),
          onLongPress: onStartSelection,
        );
      },
      orElse: () => ListTile(title: Text(habit.name)),
    );
  }

  Widget? _subtitle(
    BuildContext context, {
    required String day,
    required ({int current, int best})? streak,
    required bool skipped,
    required double amount,
    required double goal,
    required bool hasGoal,
    required FocusSession? liveSession,
  }) {
    if (liveSession != null) {
      final streakText = skipped
          ? 'Skipped - streak ${streak?.current ?? 0} - best ${streak?.best ?? 0}'
          : 'Streak ${streak?.current ?? 0} - best ${streak?.best ?? 0}';
      return _HabitLiveProgress(
        habit: habit,
        day: day,
        session: liveSession,
        loggedAmount: amount,
        streakText: streakText,
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = <Widget>[];
    final current = streak?.current ?? 0;
    final best = streak?.best ?? 0;
    if (current > 0 || best > 0 || skipped) {
      lines.add(
        Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (current > 0) _StreakPill(current: current),
            if (skipped)
              Text(
                'Skipped',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (best > 0)
              Text(
                'Best $best',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      );
    }
    if (hasGoal) {
      final progressText = formatHabitProgress(
        unit: habit.unit,
        amount: amount,
        goal: goal,
      );
      if (lines.isNotEmpty) lines.add(const SizedBox(height: AppSpace.xs));
      lines.add(
        Semantics(
          label: 'Progress $progressText',
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: (amount / goal).clamp(0.0, 1.0),
                minHeight: 4,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
      );
      lines.add(const SizedBox(height: AppSpace.xxs));
      lines.add(
        Tooltip(
          message: formatHabitExact(
            unit: habit.unit,
            amount: amount,
            goal: goal,
          ),
          child: Text(progressText),
        ),
      );
    }
    if (lines.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: lines,
    );
  }

  Future<void> _toggleDone(
    BuildContext context,
    WidgetRef ref,
    bool done,
  ) async {
    final repo = ref.read(habitRepositoryProvider);
    final day = ref.read(selectedHabitDayProvider);
    if (done) {
      await repo.logDone(habit.id, day);
    } else {
      await repo.setDone(habit.id, day, false);
    }
    ref.invalidate(habitStreakProvider(habit.id));
  }

  Future<void> _toggleSkip(
    BuildContext context,
    WidgetRef ref,
    bool skipped,
  ) async {
    final repo = ref.read(habitRepositoryProvider);
    await repo.setSkipped(
      habit.id,
      ref.read(selectedHabitDayProvider),
      skipped,
    );
    ref.invalidate(habitStreakProvider(habit.id));
  }
}

/// Live goal percentage for a habit linked to a running focus/stopwatch
/// session. The one-second ticker only exists while this widget is mounted, so
/// idle habit rows never rebuild on a clock.
class _HabitLiveProgress extends StatefulWidget {
  const _HabitLiveProgress({
    required this.habit,
    required this.day,
    required this.session,
    required this.loggedAmount,
    required this.streakText,
  });

  final Habit habit;
  final String day;
  final FocusSession session;
  final double loggedAmount;
  final String streakText;

  @override
  State<_HabitLiveProgress> createState() => _HabitLiveProgressState();
}

class _HabitLiveProgressState extends State<_HabitLiveProgress> {
  final ValueNotifier<int> _now = ValueNotifier<int>(
    DateTime.now().toUtc().millisecondsSinceEpoch,
  );
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _now.value = DateTime.now().toUtc().millisecondsSinceEpoch;
      if (!isLiveHabitProgress(
        habitId: widget.habit.id,
        selectedDayKey: widget.day,
        todayKey: habitTodayKey(),
        unit: widget.habit.unit,
        sessionHabitId: widget.session.habitId,
        sessionPhase: widget.session.phase,
      )) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.habit.goalAmount ?? 0;
    return ValueListenableBuilder<int>(
      valueListenable: _now,
      builder: (context, now, _) {
        final amount = liveHabitAmount(
          habitId: widget.habit.id,
          selectedDayKey: widget.day,
          todayKey: habitTodayKey(),
          unit: widget.habit.unit,
          loggedAmount: widget.loggedAmount,
          sessionHabitId: widget.session.habitId,
          sessionPhase: widget.session.phase,
          sessionStartUtcMs: widget.session.startUtc,
          nowMs: now,
        );
        return Tooltip(
          message: formatHabitExact(
            unit: widget.habit.unit,
            amount: amount,
            goal: goal,
          ),
          child: Text(
            '${formatHabitPercent(amount: amount, goal: goal)}  '
            '${widget.streakText}',
          ),
        );
      },
    );
  }
}

/// Compact streak badge. The flame only appears for a live streak.
class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: 'Current streak $current ${current == 1 ? 'day' : 'days'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.xxs,
          ),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 12,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: AppSpace.xxs),
              Text(
                '$current',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}
