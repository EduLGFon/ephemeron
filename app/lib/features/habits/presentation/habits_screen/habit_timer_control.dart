// Part of the habits screen library: start/stop control for minute-based
// habits that feeds the elapsed time back into the daily log.
part of '../habits_screen.dart';

class _HabitTimerControl extends StatefulWidget {
  const _HabitTimerControl({
    required this.habit,
    required this.day,
    required this.store,
    required this.repo,
    required this.strings,
    required this.onMessage,
  });

  final Habit habit;
  final String day;
  final HabitTimerStore store;
  final HabitRepository repo;
  final HabitsStrings strings;
  final void Function(String) onMessage;

  @override
  State<_HabitTimerControl> createState() => _HabitTimerControlState();
}

class _HabitTimerControlState extends State<_HabitTimerControl> {
  Timer? _timer;
  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(
    Duration.zero,
  );

  @override
  void initState() {
    super.initState();
    widget.store.active.addListener(_onActiveChanged);
    _sync();
  }

  @override
  void dispose() {
    widget.store.active.removeListener(_onActiveChanged);
    _timer?.cancel();
    _elapsed.dispose();
    super.dispose();
  }

  void _onActiveChanged() => _sync();

  void _sync() {
    _timer?.cancel();
    final active = widget.store.active.value;
    if (active != null && active.habitId == widget.habit.id) {
      _updateElapsed();
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateElapsed(),
      );
    } else {
      _elapsed.value = Duration.zero;
    }
  }

  void _updateElapsed() {
    final active = widget.store.active.value;
    if (active == null) return;
    _elapsed.value = timerElapsed(
      startedAtMs: active.startedAtMs,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool get _isRunning => widget.store.active.value?.habitId == widget.habit.id;

  Future<void> _toggle() async {
    if (_isRunning) {
      final active = widget.store.active.value!;
      final elapsed = timerElapsed(
        startedAtMs: active.startedAtMs,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      AppFeedback.success();
      await widget.repo.addAmount(
        widget.habit.id,
        active.dayKey,
        elapsedMinutes(elapsed),
      );
      await widget.store.clear();
      widget.onMessage(
        widget.strings.loggedMinutes(
          formatHabitAmount(
            unit: widget.habit.unit,
            amount: elapsedMinutes(elapsed),
          ),
        ),
      );
    } else {
      if (widget.day != habitTodayKey()) {
        AppFeedback.warning();
        widget.onMessage(widget.strings.timerOnlyToday);
        return;
      }
      if (widget.store.active.value != null) {
        AppFeedback.warning();
        widget.onMessage(widget.strings.anotherTimerRunning);
        return;
      }
      AppFeedback.tap();
      await widget.store.start(
        widget.habit.id,
        widget.day,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ValueListenableBuilder<Duration>(
      valueListenable: _elapsed,
      builder: (_, duration, _) {
        if (_isRunning) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatElapsed(duration),
                    maxLines: 1,
                    style: DsType.numeric(text.labelSmall ?? const TextStyle()),
                  ),
                ),
              ),
              AppIconButton(
                icon: Icons.stop,
                tooltip: widget.strings.stopTimer,
                semanticLabel: widget.strings.stopTimer,
                onPressed: _toggle,
              ),
            ],
          );
        }
        return AppIconButton(
          icon: Icons.play_arrow,
          tooltip: widget.strings.startTimer,
          semanticLabel: widget.strings.startTimer,
          onPressed: _toggle,
        );
      },
    );
  }
}
