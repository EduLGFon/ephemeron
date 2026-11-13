// Part of the habits screen library: habit row subtitle, live focus progress,
// and the compact streak badge.
part of '../habits_screen.dart';

Widget? _habitSubtitle(
  BuildContext context,
  Habit habit, {
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
        message: formatHabitExact(unit: habit.unit, amount: amount, goal: goal),
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
