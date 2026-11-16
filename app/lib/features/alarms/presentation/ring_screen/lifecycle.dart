part of '../ring_screen.dart';

mixin _RingScreenLifecycle on _RingScreenStateBase {
  Future<void> _startRingSound();

  static const _snoozeToast = 'Alarm snoozed for 10 min';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setImmersive(true));
    unawaited(_setWakelock(true));
    _startAutoSnooze();
    // Audio starts only after the first frame is laid out, never from the
    // native delivery path.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachRouterListener();
      unawaited(_startRingSound());
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_onRouteChanged);
    // Capture ref-backed state before super.dispose invalidates ref.
    final repo = _readRepo();
    final pendingCode = _readPendingCode();
    final needsSnooze = !_handled;
    _handled = true;
    // Belt and braces: audio never outlives the visible ring screen.
    unawaited(AlarmScheduler.stopRing());
    if (needsSnooze) unawaited(_snoozeAfterDispose(repo, pendingCode));
    unawaited(_setImmersive(false));
    unawaited(_setWakelock(false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }
    unawaited(_snoozeOnLeave(leaveRoute: true));
  }

  AlarmRepository? _readRepo() {
    try {
      return ref.read(alarmRepositoryProvider);
    } catch (_) {
      return null;
    }
  }

  int? _readPendingCode() {
    try {
      return ref.read(activeRingRequestProvider);
    } catch (_) {
      return null;
    }
  }

  Future<void> _snoozeAfterDispose(AlarmRepository? repo, int? code) async {
    if (repo == null) return;
    var snoozed = false;
    try {
      final requestCode = code ?? (await repo.latestFired())?.requestCode;
      if (requestCode != null) {
        await repo.snoozeRequest(requestCode, minutes: 10);
        snoozed = true;
      }
    } catch (_) {}
    if (snoozed) AppMessenger.show(_snoozeToast);
  }

  void _attachRouterListener() {
    try {
      final router = GoRouter.of(context);
      _router = router;
      router.routerDelegate.addListener(_onRouteChanged);
    } catch (_) {
      // Without a router the lifecycle and dispose guards still apply.
    }
  }

  /// A route replacement or push covering `/ring` counts as leaving.
  void _onRouteChanged() {
    if (_handled || _busy || !mounted) return;
    final router = _router;
    if (router == null || router.state.uri.path == '/ring') return;
    unawaited(_snoozeOnLeave(leaveRoute: false));
  }

  /// Snoozes 10 min after the screen is left without an explicit action.
  /// [leaveRoute] is false when navigation already moved away from `/ring`.
  Future<void> _snoozeOnLeave({required bool leaveRoute}) async {
    if (_handled || _busy) return;
    _handled = true;
    _auto?.cancel();
    await _snooze(
      minutes: 10,
      leaveRoute: leaveRoute,
      snackBarMessage: _snoozeToast,
    );
  }

  Future<void> _setImmersive(bool enabled) async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } catch (_) {}
  }

  Future<void> _setWakelock(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  /// Restarts the 30 s auto-snooze window; a new ring request while the
  /// screen is open must not inherit the previous alarm's remaining time.
  void _startAutoSnooze() {
    if (_busy || _handled) return;
    _auto?.cancel();
    _auto = Timer(const Duration(seconds: 30), () {
      unawaited(_snoozeOnLeave(leaveRoute: true));
    });
  }
}
