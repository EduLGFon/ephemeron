// Part of the habits screen library: one habit row with one-tap logging,
// decrement, skip, timer/progress actions, and selection support.
part of '../habits_screen.dart';

HabitLog? _logFor(List<HabitLog> logs, String day) {
  for (final l in logs) {
    if (l.dayKey == day) return l;
  }
  return null;
}

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
            onChanged: (_) => selecting
                ? onToggleSelection()
                : _toggleDone(context, ref, !done),
          ),
          title: Text(
            habit.name,
            style: done
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: streakAsync.maybeWhen(
            data: (st) {
              final streakText = skipped
                  ? 'Skipped - streak ${st.current} - best ${st.best}'
                  : 'Streak ${st.current} - best ${st.best}';
              if (liveSession != null) {
                return _HabitLiveProgress(
                  habit: habit,
                  day: day,
                  session: liveSession,
                  loggedAmount: amount,
                  streakText: streakText,
                );
              }
              final progress = hasGoal
                  ? formatHabitProgress(
                      unit: habit.unit,
                      amount: amount,
                      goal: goal,
                    )
                  : null;
              if (progress == null) return Text(streakText);
              return Tooltip(
                message: formatHabitExact(
                  unit: habit.unit,
                  amount: amount,
                  goal: goal,
                ),
                child: Text('$progress  $streakText'),
              );
            },
            orElse: () => hasGoal
                ? Tooltip(
                    message: formatHabitExact(
                      unit: habit.unit,
                      amount: amount,
                      goal: goal,
                    ),
                    child: Text(
                      formatHabitProgress(
                        unit: habit.unit,
                        amount: amount,
                        goal: goal,
                      ),
                    ),
                  )
                : null,
          ),
          trailing: selecting
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasGoal && amount > 0)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        icon: const Icon(Icons.remove),
                        tooltip: 'Subtract ${_fmt(step)}',
                        onPressed: () async {
                          await repo.subtractAmount(habit.id, day, step);
                          ref.invalidate(habitStreakProvider(habit.id));
                        },
                      ),
                    if (hasGoal)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        icon: const Icon(Icons.add),
                        tooltip: 'Add ${_fmt(step)}',
                        onPressed: () async {
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
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(m)));
                          }
                        },
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
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
                      onPressed: () => _toggleSkip(context, ref, !skipped),
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

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}
