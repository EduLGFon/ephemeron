// Part of the focus screen library: setup, presets, links, pause banner,
// today totals and recent sessions.
part of 'focus_screen.dart';

enum _FocusMode { focus, breakTime, stopwatch }

class _StartView extends ConsumerStatefulWidget {
  const _StartView({
    required this.paused,
    required this.onStarted,
    required this.onPausedCleared,
  });

  final PausedFocusSegment? paused;
  final VoidCallback onStarted;
  final VoidCallback onPausedCleared;

  @override
  ConsumerState<_StartView> createState() => _StartViewState();
}

class _StartViewState extends ConsumerState<_StartView> {
  int _focusMin = 25;
  int _breakMin = 5;
  _FocusMode _mode = _FocusMode.focus;
  String? _taskId;
  String? _habitId;
  String? _alarmPreset = AlarmPreset.notification.id;
  bool _setupRestored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_setupRestored) {
      _setupRestored = true;
      Future.microtask(() async {
        try {
          final repo = await ref.read(settingsRepositoryProvider.future);
          if (!mounted) return;
          setState(() {
            _focusMin = repo.focusSetupMin;
            _breakMin = repo.focusBreakMin;
            // Stopwatch is not persisted; only focus/break survive restart.
            _mode = repo.focusIsBreak ? _FocusMode.breakTime : _FocusMode.focus;
            _taskId = repo.focusTaskId;
            _habitId = repo.focusHabitId;
          });
        } catch (_) {
          // Setup is a convenience; defaults still start a session.
        }
      });
    }
  }

  Future<void> _persistSetup() async {
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.setFocusSetup(
        focusMin: _focusMin,
        breakMin: _breakMin,
        isBreak: _mode == _FocusMode.breakTime,
        taskId: () => _taskId,
        habitId: () => _habitId,
      );
    } catch (_) {
      // A failed save must not block starting a session.
    }
  }

  int get _currentMinutes =>
      _mode == _FocusMode.breakTime ? _breakMin : _focusMin;

  String _customChipLabel(FocusStrings strings) {
    final presets = _mode == _FocusMode.breakTime
        ? _breakPresets
        : _focusPresets;
    return presets.contains(_currentMinutes)
        ? strings.custom
        : strings.customMinutes(_currentMinutes);
  }

  Future<void> _editCustomDuration() async {
    final isBreak = _mode == _FocusMode.breakTime;
    final minutes = await showAppDialog<int>(
      context: context,
      builder: (_) => _CustomDurationDialog(
        isBreak: isBreak,
        initialMinutes: _currentMinutes,
      ),
    );
    if (minutes == null || !mounted) return;
    AppFeedback.success();
    setState(() {
      if (isBreak) {
        _breakMin = minutes;
      } else {
        _focusMin = minutes;
      }
    });
    _persistSetup();
  }

  bool _handlingPendingNext = false;

  @override
  Widget build(BuildContext context) {
    final strings = FocusStrings.of(context);
    ref.listen<String?>(pendingFocusNextProvider, (prev, next) {
      if (next == null || _handlingPendingNext || !mounted) return;
      _handlingPendingNext = true;
      ref.read(pendingFocusNextProvider.notifier).set(null);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() {
          _mode = next == 'break' ? _FocusMode.breakTime : _FocusMode.focus;
        });
        await _start(context, ref);
        _handlingPendingNext = false;
      });
    });
    final tasksAsync = ref.watch(linkableTasksProvider);
    final habitsAsync = ref.watch(linkableHabitsProvider);
    final paused = widget.paused;
    return ListView(
      padding: const EdgeInsets.only(bottom: DsSpace.x48),
      children: [
        if (paused != null) ...[
          _PausedBanner(
            segment: paused,
            strings: strings,
            onResume: () => _resume(context, ref),
            onDiscard: widget.onPausedCleared,
          ),
          const SizedBox(height: DsSpace.x12),
        ],
        Wrap(
          spacing: DsSpace.x8,
          runSpacing: DsSpace.x8,
          children: [
            AppFilterChip(
              label: strings.modeFocus,
              selected: _mode == _FocusMode.focus,
              onSelected: (_) => _selectMode(_FocusMode.focus),
            ),
            AppFilterChip(
              label: strings.modeBreak,
              selected: _mode == _FocusMode.breakTime,
              onSelected: (_) => _selectMode(_FocusMode.breakTime),
            ),
            AppFilterChip(
              label: strings.modeStopwatch,
              selected: _mode == _FocusMode.stopwatch,
              onSelected: (_) => _selectMode(_FocusMode.stopwatch),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.x12),
        if (_mode != _FocusMode.stopwatch) ...[
          Wrap(
            spacing: DsSpace.x8,
            runSpacing: DsSpace.x8,
            children: [
              for (final minutes
                  in (_mode == _FocusMode.breakTime
                      ? _breakPresets
                      : _focusPresets))
                AppChip(
                  label: strings.minutes(minutes),
                  selected: _currentMinutes == minutes,
                  onTap: () => _selectPreset(minutes),
                ),
              AppChip(
                label: _customChipLabel(strings),
                icon: Icons.tune,
                onTap: _editCustomDuration,
              ),
            ],
          ),
          const SizedBox(height: DsSpace.x12),
        ],
        tasksAsync.maybeWhen(
          data: (tasks) => DropdownButtonFormField<String?>(
            initialValue: _taskId,
            isExpanded: true,
            decoration: InputDecoration(labelText: strings.linkTask),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(strings.none)),
              for (final task in tasks.take(50))
                DropdownMenuItem<String?>(
                  value: task.id,
                  child: Text(task.title),
                ),
            ],
            onChanged: (value) {
              setState(() => _taskId = value);
              _persistSetup();
            },
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: DsSpace.x8),
        habitsAsync.maybeWhen(
          data: (habits) => DropdownButtonFormField<String?>(
            initialValue: _habitId,
            isExpanded: true,
            decoration: InputDecoration(labelText: strings.linkHabit),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(strings.none)),
              for (final habit in habits)
                DropdownMenuItem<String?>(
                  value: habit.id,
                  child: Text(habit.name),
                ),
            ],
            onChanged: (value) {
              setState(() => _habitId = value);
              _persistSetup();
            },
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        if (_mode != _FocusMode.stopwatch) ...[
          const SizedBox(height: DsSpace.x12),
          AlarmPresetPicker(
            value: _alarmPreset,
            onChanged: (value) => setState(() => _alarmPreset = value),
          ),
        ],
        const SizedBox(height: DsSpace.x16),
        AppButton(
          label: _startLabel(strings),
          icon: Icons.play_arrow,
          expand: true,
          onPressed: () => _start(context, ref),
        ),
        const SizedBox(height: DsSpace.x16),
        const _FocusHistorySection(),
      ],
    );
  }

  String _startLabel(FocusStrings strings) {
    return switch (_mode) {
      _FocusMode.stopwatch => strings.startStopwatch,
      _FocusMode.breakTime => strings.startLabel('break', _breakMin),
      _FocusMode.focus => strings.startLabel('focus', _focusMin),
    };
  }

  void _selectMode(_FocusMode mode) {
    if (_mode == mode) return;
    AppFeedback.selection();
    setState(() => _mode = mode);
    _persistSetup();
  }

  void _selectPreset(int minutes) {
    AppFeedback.selection();
    setState(() {
      if (_mode == _FocusMode.breakTime) {
        _breakMin = minutes;
      } else {
        _focusMin = minutes;
      }
    });
    _persistSetup();
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final isStopwatch = _mode == _FocusMode.stopwatch;
    final phase = isStopwatch
        ? 'stopwatch'
        : (_mode == _FocusMode.breakTime ? 'break' : 'focus');
    await _startSession(
      context,
      ref,
      taskId: _taskId,
      habitId: _habitId,
      durationMin: isStopwatch
          ? null
          : (_mode == _FocusMode.breakTime ? _breakMin : _focusMin),
      phase: phase,
      alarmPreset: isStopwatch ? null : _alarmPreset,
    );
    if (!mounted) return;
    widget.onPausedCleared();
    widget.onStarted();
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final segment = widget.paused;
    if (segment == null) return;
    await _startSession(
      context,
      ref,
      taskId: segment.taskId,
      habitId: segment.habitId,
      durationMin: segment.isStopwatch ? null : segment.remainingMinutes,
      phase: segment.phase,
      alarmPreset: segment.alarmPreset,
      note: segment.note,
    );
    if (!mounted) return;
    widget.onPausedCleared();
    widget.onStarted();
  }
}
