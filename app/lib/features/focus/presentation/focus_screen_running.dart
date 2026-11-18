// Part of the focus screen library: the running session view. The ticker only
// updates the isolated face, elapsed label and linked habit progress.
part of 'focus_screen.dart';

class _RunningView extends ConsumerStatefulWidget {
  const _RunningView({required this.session, required this.onPaused});

  final FocusSession session;
  final ValueChanged<PausedFocusSegment> onPaused;

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
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
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

  void _tick() {
    if (!mounted) return;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    _now.value = nowMs;
    final target = widget.session.targetEndUtc;
    if (target != null && nowMs >= target && !_completionNotified) {
      _completionNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCompletionSuggestion(context, _elapsedMinutes(nowMs));
      });
    }
  }

  int _elapsedMinutes(int nowMs) =>
      ((nowMs - widget.session.startUtc) / msPerMinute).floor();

  /// A suspended app can miss several ticks. Refresh once on resume so the
  /// timestamp-based countdown never looks frozen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _tick();
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
    } catch (_) {
      // Notes are best-effort; finish still records the session.
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = FocusStrings.of(context);
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
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final finished = target != null && nowMs >= target;
      if (!finished) return;
      _handlingPendingNext = true;
      ref.read(pendingFocusNextProvider.notifier).set(null);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _completeAndStartPhase(
          context,
          ref,
          _elapsedMinutes(nowMs),
          startBreak: next == 'break',
        );
        _handlingPendingNext = false;
      });
    });
    final linkedHabit = habitAsync?.value;
    final goal = linkedHabit?.goalAmount ?? 0;
    final showHabitProgress =
        linkedHabit != null && isMinuteUnit(linkedHabit.unit) && goal > 0;
    var loggedAmount = 0.0;
    if (showHabitProgress) {
      final todayKey = habitDateKey(DateTime.now());
      for (final log in logsAsync?.value ?? const <HabitLog>[]) {
        if (log.dayKey == todayKey) {
          loggedAmount = log.amount;
          break;
        }
      }
    }
    final abandoned =
        DateTime.now().toUtc().millisecondsSinceEpoch -
            widget.session.startUtc >
        12 * msPerHour;
    final isStopwatch = widget.session.targetEndUtc == null;
    return ListView(
      padding: const EdgeInsets.only(top: DsSpace.x8, bottom: DsSpace.x48),
      children: [
        if (abandoned)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.x12),
            child: AppSurface(
              tonal: true,
              padding: const EdgeInsets.all(DsSpace.x12),
              child: Text(
                strings.recovered(
                  _elapsedMinutes(
                    DateTime.now().toUtc().millisecondsSinceEpoch,
                  ),
                ),
              ),
            ),
          ),
        _CompletionCard(
          now: _now,
          session: widget.session,
          strings: strings,
          onCompleteNext: (elapsedMin) =>
              _completeAndStartNext(context, ref, elapsedMin),
        ),
        const SizedBox(height: DsSpace.x8),
        Center(
          child: FocusTimeFace(
            now: _now,
            session: widget.session,
            strings: strings,
          ),
        ),
        const SizedBox(height: DsSpace.x8),
        FocusElapsedLabel(now: _now, session: widget.session, strings: strings),
        if (showHabitProgress) ...[
          const SizedBox(height: DsSpace.x16),
          _LinkedHabitProgress(
            habit: linkedHabit,
            loggedAmount: loggedAmount,
            session: widget.session,
            now: _now,
          ),
        ],
        const SizedBox(height: DsSpace.x16),
        AppTextField(
          controller: _noteController,
          labelText: strings.notesLabel,
          maxLines: 4,
          minLines: 1,
        ),
        const SizedBox(height: DsSpace.x24),
        Wrap(
          spacing: DsSpace.x8,
          runSpacing: DsSpace.x8,
          children: [
            if (!isStopwatch)
              AppButton(
                label: strings.pause,
                icon: Icons.pause,
                variant: AppButtonVariant.secondary,
                onPressed: () => _pause(context, ref),
              ),
            AppButton(
              label: strings.finish,
              icon: Icons.stop,
              onPressed: () => _finish(
                context,
                ref,
                _elapsedMinutes(DateTime.now().toUtc().millisecondsSinceEpoch),
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.x8),
        AppButton(
          label: strings.discard,
          variant: AppButtonVariant.ghost,
          onPressed: () => _discard(context, ref),
        ),
      ],
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.now,
    required this.session,
    required this.strings,
    required this.onCompleteNext,
  });

  final ValueListenable<int> now;
  final FocusSession session;
  final FocusStrings strings;
  final ValueChanged<int> onCompleteNext;

  @override
  Widget build(BuildContext context) {
    final target = session.targetEndUtc;
    if (target == null) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: now,
      builder: (context, nowMs, _) {
        if (nowMs < target) return const SizedBox.shrink();
        final isBreak = session.phase == 'break';
        final elapsed = ((nowMs - session.startUtc) / msPerMinute).floor();
        return Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.x12),
          child: AppSurface(
            tonal: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.overtime,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: DsSpace.x4),
                Text(strings.overtimeBody(elapsed, isBreak)),
                const SizedBox(height: DsSpace.x12),
                AppButton(
                  label: isBreak
                      ? strings.completeAndStartFocus
                      : strings.completeAndStartBreak,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => onCompleteNext(elapsed),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
