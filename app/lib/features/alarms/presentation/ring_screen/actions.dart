part of '../ring_screen.dart';

mixin _RingScreenActions on _RingScreenStateBase {
  String _baseSourceId(String sourceId) {
    final at = sourceId.indexOf('@');
    if (at >= 0) return sourceId.substring(0, at);
    final hash = sourceId.indexOf('#');
    return hash >= 0 ? sourceId.substring(0, hash) : sourceId;
  }

  /// Loads the ring row for the active request code, falling back to the
  /// latest fired alarm when the route was opened without a request.
  // ignore: unused_element
  Future<AlarmsIndexData?> _loadAlarm(int? requestCode) {
    final repo = ref.read(alarmRepositoryProvider);
    if (requestCode != null) return repo.byRequestCode(requestCode);
    return repo.latestFired();
  }

  /// Request code for the actions: the active native ring request wins,
  /// then the loaded row.
  // ignore: unused_element
  int? _requestCode(AlarmsIndexData? alarm) =>
      ref.read(activeRingRequestProvider) ?? alarm?.requestCode;

  Future<int?> _resolveCode(int? code) async {
    if (code != null) return code;
    final active = ref.read(activeRingRequestProvider);
    if (active != null) return active;
    try {
      return (await ref.read(alarmRepositoryProvider).latestFired())
          ?.requestCode;
    } catch (_) {
      return null;
    }
  }

  // ignore: unused_element
  Future<bool> _isNumericHabit(String? sourceType, String? sourceId) async {
    if (sourceType == null || sourceId == null) return false;
    if (sourceType != 'habit' && sourceType != 'habit_reminder') return false;
    final db = ref.read(appDatabaseProvider);
    final habit = await (db.select(
      db.habits,
    )..where((h) => h.id.equals(_baseSourceId(sourceId)))).getSingleOrNull();
    return (habit?.goalAmount ?? 0) > 0;
  }

  // ignore: unused_element
  @override
  Future<void> _snooze({
    int minutes = 10,
    int? code,
    bool leaveRoute = true,
    String? snackBarMessage,
  }) async {
    await _act(
      code,
      (requestCode) => ref
          .read(alarmRepositoryProvider)
          .snoozeRequest(requestCode, minutes: minutes),
      rebuild: false,
      leaveRoute: leaveRoute,
      snackBarMessage: snackBarMessage,
    );
  }

  /// Starts native audio only after the ring screen's first frame. The stored
  /// row must still be firing; notification presets never ring.
  // ignore: unused_element
  Future<void> _startRingSound() async {
    if (_handled || !mounted) return;
    try {
      final repo = ref.read(alarmRepositoryProvider);
      final active = ref.read(activeRingRequestProvider);
      final row = active != null
          ? await repo.byRequestCode(active)
          : await repo.latestFired();
      if (row == null || !canOpenRingScreen(row.state)) return;
      final preset = AlarmPreset.tryParse(row.preset);
      final code = row.requestCode;
      if (code == null || preset == null || !preset.usesFullScreen) return;
      await AlarmScheduler.startRing(code);
    } catch (_) {
      // No sound when the fired row cannot be verified.
    }
  }

  /// Runs one ring action, then clears the verified ring request and leaves.
  /// Done/Dismiss rebuild the alarm window so the next occurrence is
  /// scheduled; Snooze must not rebuild because that would cancel the snooze.
  /// [destination] replaces the ring route with a section tab (Open item);
  /// null keeps the existing pop-or-calendar behavior.
  /// [successFeedback] fires the success haptic only after the action resolves.
  /// [leaveRoute] is false when the route already changed under the screen.
  /// [snackBarMessage] is shown through the root messenger after a successful
  /// auto-snooze so it survives route disposal. Explicit actions pass none.
  /// The rebuild is fire-and-forget so the route change lands before the
  /// biometric gate replaces the app subtree.
  @override
  Future<void> _act(
    int? code,
    Future<void> Function(int requestCode) action, {
    required bool rebuild,
    String? destination,
    bool successFeedback = false,
    bool leaveRoute = true,
    String? snackBarMessage,
  }) async {
    if (_busy) return;
    _busy = true;
    _handled = true;
    _auto?.cancel();
    var acted = false;
    try {
      final requestCode = await _resolveCode(code);
      if (requestCode != null) {
        await action(requestCode);
        acted = true;
        if (successFeedback && mounted) AppFeedback.success();
      }
    } catch (_) {
      // The native notification/ring is already stopped; never trap the
      // user on the ring screen because of a DB failure.
    } finally {
      if (mounted) {
        ref.read(activeRingRequestProvider.notifier).clear();
        if (rebuild) {
          final repo = ref.read(alarmRepositoryProvider);
          unawaited(_rebuildWindow(repo));
        }
        if (leaveRoute) _leaveRing(destination: destination);
      }
      if (acted && snackBarMessage != null) AppMessenger.show(snackBarMessage);
    }
  }

  Future<void> _rebuildWindow(AlarmRepository repo) async {
    try {
      await repo.rebuildWindow();
    } catch (_) {}
  }

  void _leaveRing({String? destination}) {
    if (!mounted) return;
    try {
      if (destination != null) {
        // Replace the ring route instead of popping so a section tab always
        // wins, even when the ring was opened as the first route.
        context.go(destination);
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/tab0');
      }
    } catch (_) {
      if (mounted) context.go(destination ?? '/tab0');
    }
  }
}
