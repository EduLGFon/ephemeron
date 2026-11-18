// Part of the focus screen library: pause, finish, complete-next, discard and
// the completion suggestion.
part of 'focus_screen.dart';

extension _RunningViewActions on _RunningViewState {
  Future<void> _showCompletionSuggestion(
    BuildContext context,
    int elapsedMin,
  ) async {
    AppFeedback.success();
    if (!mounted) return;
    final strings = FocusStrings.of(context);
    final isBreak = widget.session.phase == 'break';
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isBreak ? strings.completeTitleBreak : strings.completeTitleFocus,
        ),
        content: Text(strings.completionBody(elapsedMin, isBreak)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.notNow),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _completeAndStartNext(context, ref, elapsedMin);
            },
            child: Text(isBreak ? strings.startFocus : strings.startBreak),
          ),
        ],
      ),
    );
  }

  Future<int?> _completeSession(WidgetRef ref) async {
    await _flushNote();
    if (!mounted) return null;
    final repo = ref.read(focusRepositoryProvider);
    final note = _noteController.text.trim();
    final kept = await repo.finishSession(
      widget.session.id,
      note: note.isEmpty ? null : note,
    );
    await AlarmScheduler.cancel(_requestCode(widget.session.id));
    await SystemLauncher.stopFocusChronometer();
    try {
      final settings = await ref.read(settingsRepositoryProvider.future);
      if (settings.focusDnd) await SystemLauncher.setDnd(false);
    } catch (_) {
      // DND is best-effort; the session is already finished.
    }
    final habitId = widget.session.habitId;
    final isBreak = widget.session.phase == 'break';
    if (habitId != null && kept > 0 && !isBreak && mounted) {
      await _creditHabit(context, ref, habitId, kept);
    }
    return kept;
  }

  Future<void> _pause(BuildContext context, WidgetRef ref) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final target = widget.session.targetEndUtc;
    final rawRemaining = target == null ? null : target - nowMs;
    final remainingMs = rawRemaining == null
        ? null
        : (rawRemaining < 0 ? 0 : rawRemaining);
    if (remainingMs != null && remainingMs <= 0) {
      await _finish(context, ref, _elapsedMinutes(nowMs));
      return;
    }
    final note = _noteController.text.trim();
    final kept = await _completeSession(ref);
    if (kept == null || !mounted) return;
    AppFeedback.success();
    widget.onPaused(
      PausedFocusSegment(
        remainingMs: remainingMs,
        phase: widget.session.phase ?? 'focus',
        taskId: widget.session.taskId,
        habitId: widget.session.habitId,
        alarmPreset: widget.session.alarmPreset,
        note: note.isEmpty ? null : note,
      ),
    );
    _refresh(ref);
  }

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    int elapsedMin,
  ) async {
    final strings = FocusStrings.of(context);
    final isBreak = widget.session.phase == 'break';
    final phase = isBreak ? strings.modeBreak : strings.modeFocus;
    final target = widget.session.targetEndUtc;
    final String copy;
    if (target == null) {
      copy = strings.stopDialogBodyStopwatch(elapsedMin);
    } else {
      final totalMin = ((target - widget.session.startUtc) / msPerMinute)
          .floor();
      final remainingMin = (totalMin - elapsedMin).clamp(0, totalMin).toInt();
      copy = remainingMin > 0
          ? strings.stopDialogBody(elapsedMin, remainingMin, phase)
          : strings.stopDialogBodyNoRemainder(elapsedMin, phase);
    }
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.finishDialogTitle),
        content: Text(copy),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.stop),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final kept = await _completeSession(ref);
    if (kept != null) AppFeedback.success();
    _refresh(ref);
  }

  Future<void> _completeAndStartNext(
    BuildContext context,
    WidgetRef ref,
    int elapsedMin,
  ) async {
    await _completeAndStartPhase(
      context,
      ref,
      elapsedMin,
      startBreak: widget.session.phase != 'break',
    );
  }

  Future<void> _completeAndStartPhase(
    BuildContext context,
    WidgetRef ref,
    int elapsedMin, {
    required bool startBreak,
  }) async {
    final kept = await _completeSession(ref);
    if (kept == null || !mounted) return;
    AppFeedback.success();
    await _startNextSession(ref, startBreak: startBreak);
  }

  Future<void> _startNextSession(
    WidgetRef ref, {
    required bool startBreak,
  }) async {
    var durationMin = startBreak ? 5 : 25;
    try {
      final settings = await ref.read(settingsRepositoryProvider.future);
      durationMin = startBreak
          ? settings.focusBreakMin
          : settings.focusSetupMin;
    } catch (_) {
      // Defaults keep the chain moving when setup cannot load.
    }
    if (!mounted) return;
    await _startSession(
      context,
      ref,
      taskId: widget.session.taskId,
      habitId: widget.session.habitId,
      durationMin: durationMin,
      phase: startBreak ? 'break' : 'focus',
      alarmPreset: AlarmPreset.notification.id,
    );
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final strings = FocusStrings.of(context);
    final pending = ref.read(pendingOperationsProvider);
    final opId = await pending.scheduleFocusDelete(widget.session.id);
    await AlarmScheduler.cancel(_requestCode(widget.session.id));
    await SystemLauncher.stopFocusChronometer();
    try {
      final settings = await ref.read(settingsRepositoryProvider.future);
      if (settings.focusDnd) await SystemLauncher.setDnd(false);
    } catch (_) {
      // DND is best-effort.
    }
    _refresh(ref);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      strings.sessionDiscarded,
      onUndo: () => pending.cancel(opId),
    );
  }
}

/// Owns the controller for its whole route lifetime so it is disposed with
/// the dialog State, never while the route is still animating out.
class _CustomDurationDialog extends StatefulWidget {
  const _CustomDurationDialog({
    required this.isBreak,
    required this.initialMinutes,
  });

  final bool isBreak;
  final int initialMinutes;

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  late final TextEditingController _controller;
  String? _error;

  int get _max => widget.isBreak ? 60 : 240;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialMinutes}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final validation = validateFocusMinutes(
      _controller.text,
      isBreak: widget.isBreak,
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    Navigator.of(context).pop(int.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final strings = FocusStrings.of(context);
    return AlertDialog(
      title: Text(
        widget.isBreak
            ? '${strings.custom} ${strings.modeBreak}'
            : '${strings.custom} ${strings.modeFocus}',
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: strings.minutesLabel,
          helperText: '1-$_max min',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(strings.useDuration)),
      ],
    );
  }
}
