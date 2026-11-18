// Part of the habits screen library: pure log lookups and display helpers
// shared by the row and its live focus progress wrapper.
part of '../habits_screen.dart';

HabitLog? _logFor(List<HabitLog> logs, String day) {
  for (final log in logs) {
    if (log.dayKey == day) return log;
  }
  return null;
}

bool _logDone(Habit habit, HabitLog? log) {
  if (log == null) return false;
  if (log.done) return true;
  final goal = habit.goalAmount ?? 0;
  return goal > 0 && log.amount >= goal;
}

double _habitProgress(Habit habit, HabitLog? log) {
  final goal = habit.goalAmount ?? 0;
  if (goal > 0) {
    return ((log?.amount ?? 0) / goal).clamp(0.0, 1.0);
  }
  return _logDone(habit, log) ? 1.0 : 0.0;
}

/// Filled dots for the last seven days, oldest first. A day counts when it
/// reached the goal for goal habits or was marked done for binary habits.
List<bool> _habitWeekDots(Habit habit, List<HabitLog> logs, DateTime today) {
  final base = DateTime(today.year, today.month, today.day);
  return [
    for (var i = 6; i >= 0; i--)
      _logDone(
        habit,
        _logFor(logs, habitDateKey(base.subtract(Duration(days: i)))),
      ),
  ];
}

String? _habitSubtitle(Habit habit, HabitLog? log, HabitsStrings strings) {
  if (log?.skipped == true) return strings.skipped;
  final goal = habit.goalAmount ?? 0;
  final done = _logDone(habit, log);
  if (done) return strings.done;
  if (goal <= 0) return null;
  return formatHabitProgress(
    unit: habit.unit,
    amount: log?.amount ?? 0,
    goal: goal,
  );
}

String _stepLabel(Habit habit) {
  final step = habit.increment ?? 1.0;
  return step == step.roundToDouble()
      ? step.toInt().toString()
      : step.toString();
}

/// Rebuilds only its own row while a linked focus/stopwatch session runs.
class _LiveHabitTile extends StatefulWidget {
  const _LiveHabitTile({
    required this.session,
    required this.habit,
    required this.day,
    required this.loggedAmount,
    required this.builder,
  });

  final FocusSession session;
  final Habit habit;
  final String day;
  final double loggedAmount;
  final Widget Function(double amount) builder;

  @override
  State<_LiveHabitTile> createState() => _LiveHabitTileState();
}

class _LiveHabitTileState extends State<_LiveHabitTile> {
  final ValueNotifier<int> _now = ValueNotifier<int>(
    DateTime.now().toUtc().millisecondsSinceEpoch,
  );
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _now.value = DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        return widget.builder(amount);
      },
    );
  }
}
