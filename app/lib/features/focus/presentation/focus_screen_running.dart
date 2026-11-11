part of 'focus_screen.dart';

class _RunningView extends ConsumerStatefulWidget {
  const _RunningView({required this.session});

  final FocusSession session;

  @override
  ConsumerState<_RunningView> createState() => _RunningViewState();
}

class _RunningViewState extends ConsumerState<_RunningView>
    with WidgetsBindingObserver {
  Timer? _ticker;
  Timer? _noteDebounce;
  final ValueNotifier<int> _now = ValueNotifier<int>(
    DateTime.now().toUtc().millisecondsSinceEpoch,
  );
  final TextEditingController _noteController = TextEditingController();
  bool _completionNotified = false;
  bool _handlingPendingNext = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _noteController.text = widget.session.note ?? '';
    _noteController.addListener(_onNoteChanged);
    WakelockPlus.enable();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _now.value = DateTime.now().toUtc().millisecondsSinceEpoch;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noteDebounce?.cancel();
    _flushNote();
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    _ticker?.cancel();
    _now.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  /// A suspended app can miss several ticks. Refresh once on resume so the
  /// timestamp-based countdown never looks frozen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _now.value = DateTime.now().toUtc().millisecondsSinceEpoch;
    }
  }

  void _onNoteChanged() {
    _noteDebounce?.cancel();
    _noteDebounce = Timer(const Duration(milliseconds: 400), _flushNote);
  }

  Future<void> _flushNote() async {
    _noteDebounce?.cancel();
    try {
      await ref
          .read(focusRepositoryProvider)
          .updateNote(
            widget.session.id,
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final habitId = widget.session.habitId;
    final habitAsync = habitId == null
        ? null
        : ref.watch(habitByIdProvider(habitId));
    final logsAsync = habitId == null
        ? null
        : ref.watch(habitLogsProvider(habitId));
    ref.listen<String?>(pendingFocusNextProvider, (prev, next) {
      if (next == null || _handlingPendingNext || !mounted) return;
      final target = widget.session.targetEndUtc;
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final finished = target != null && now >= target;
      if (!finished) return;
      _handlingPendingNext = true;
      ref.read(pendingFocusNextProvider.notifier).set(null);
      final elapsedMin = ((now - widget.session.startUtc) / msPerMinute)
          .floor();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _completeAndStartPhase(
          context,
          ref,
          elapsedMin,
          startBreak: next == 'break',
        );
        _handlingPendingNext = false;
      });
    });
    return ValueListenableBuilder<int>(
      valueListenable: _now,
      builder: (context, now, _) {
        final target = widget.session.targetEndUtc;
        final isStopwatch = target == null;
        final elapsedMs = now - widget.session.startUtc;
        final elapsedMin = (elapsedMs / msPerMinute).floor();
        final remainingMs = isStopwatch ? 0 : target - now;
        final finished = !isStopwatch && remainingMs <= 0;
        if (finished && !_completionNotified) {
          _completionNotified = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showCompletionSuggestion(context, elapsedMin);
          });
        }
        final elapsed = _formatElapsed(elapsedMs);
        final display = isStopwatch
            ? elapsed
            : formatFocusCountdown(remainingMs);
        final totalMs = isStopwatch ? 0 : target - widget.session.startUtc;
        final ringProgress = isStopwatch
            ? null
            : (totalMs <= 0
                  ? 1.0
                  : (elapsedMs / totalMs).clamp(0.0, 1.0).toDouble());
        final isBreak = widget.session.phase == 'break';
        final nextLabel = isBreak ? 'Start focus' : 'Start break';
        final todayKey = habitDateKey(DateTime.now());
        final linkedHabit = habitAsync?.value;
        final goal = linkedHabit?.goalAmount ?? 0;
        final showHabitProgress =
            linkedHabit != null && isMinuteUnit(linkedHabit.unit) && goal > 0;
        var loggedAmount = 0.0;
        for (final log in logsAsync?.value ?? const <HabitLog>[]) {
          if (log.dayKey == todayKey) {
            loggedAmount = log.amount;
            break;
          }
        }
        final liveAmount = showHabitProgress
            ? liveHabitAmount(
                habitId: linkedHabit.id,
                selectedDayKey: todayKey,
                todayKey: todayKey,
                unit: linkedHabit.unit,
                loggedAmount: loggedAmount,
                sessionHabitId: widget.session.habitId,
                sessionPhase: widget.session.phase,
                sessionStartUtcMs: widget.session.startUtc,
                nowMs: now,
              )
            : loggedAmount;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isAbandoned(now))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Recovered after app restart. Finishing keeps $elapsedMin min.',
                    ),
                  ),
                ),
              if (finished)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBreak
                              ? 'Break over - $elapsedMin min elapsed.'
                              : 'Focus complete - $elapsedMin min elapsed.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () =>
                              _completeAndStartNext(context, ref, elapsedMin),
                          child: Text('Complete and $nextLabel'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.xl),
              Center(
                child: _CountdownFace(
                  display: display,
                  semanticsLabel: isStopwatch
                      ? 'Focus elapsed time: $display'
                      : 'Focus time remaining: $display',
                  progress: ringProgress,
                  isBreak: isBreak,
                  // Shorter screens keep the action buttons visible.
                  diameter: MediaQuery.sizeOf(context).height < 700 ? 160 : 240,
                ),
              ),
              Center(
                child: Text(
                  '${widget.session.phase ?? 'focus'} - $elapsedMin min elapsed',
                ),
              ),
              if (linkedHabit != null && showHabitProgress) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          linkedHabit.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (liveAmount / goal).clamp(0.0, 1.0),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatHabitPercent(amount: liveAmount, goal: goal)}'
                          ' - '
                          '${formatHabitExact(unit: linkedHabit.unit, amount: liveAmount, goal: goal)}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _finish(context, ref, elapsedMin),
                icon: const Icon(Icons.stop),
                label: Text(finished ? 'Complete' : 'Finish'),
              ),
              if (finished) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _completeAndStartNext(context, ref, elapsedMin),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(nextLabel),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _discard(context, ref),
                child: const Text('Discard session'),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isAbandoned(int now) => now - widget.session.startUtc > 12 * msPerHour;
}

/// Timed focus and breaks get a calm ring; stopwatch keeps plain elapsed text.
/// [progress] is null for stopwatch and is already clamped by the caller.
class _CountdownFace extends StatelessWidget {
  const _CountdownFace({
    required this.display,
    required this.semanticsLabel,
    required this.progress,
    required this.isBreak,
    required this.diameter,
  });

  final String display;
  final String semanticsLabel;
  final double? progress;
  final bool isBreak;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final text = Semantics(
      label: semanticsLabel,
      child: Text(display, style: Theme.of(context).textTheme.displayLarge),
    );
    final value = progress;
    if (value == null) return text;
    final scheme = Theme.of(context).colorScheme;
    final compact = diameter < 200;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: compact ? 6 : 8,
              color: isBreak ? scheme.tertiary : scheme.primary,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? AppSpace.lg : AppSpace.xxl),
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: text),
            ),
          ),
        ],
      ),
    );
  }
}
