part of '../ring_screen.dart';

mixin _RingScreenLifecycle on _RingScreenStateBase {
  Future<void> _snooze();

  @override
  void initState() {
    super.initState();
    unawaited(_setImmersive(true));
    unawaited(_setWakelock(true));
    _startAutoSnooze();
  }

  @override
  void dispose() {
    _auto?.cancel();
    unawaited(_setImmersive(false));
    unawaited(_setWakelock(false));
    super.dispose();
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
    if (_busy) return;
    _auto?.cancel();
    _auto = Timer(const Duration(seconds: 30), () {
      unawaited(_snooze());
    });
  }
}
