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
          subtitle: _habitSubtitle(
            context,
            habit,
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

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}
