// A minimal focus-session clock. Time is read through an injected [now]
// function so elapsed time stays deterministic in tests. A single periodic
// timer ticks once per second and recomputes [elapsed].
import 'dart:async';

import 'package:flutter/foundation.dart';

class FocusClock {
  FocusClock({
    required this.now,
    this._tickInterval = const Duration(seconds: 1),
  });

  /// Injected clock; must never be [DateTime.now] in tests.
  final DateTime Function() now;

  final Duration _tickInterval;

  final ValueNotifier<Duration> elapsed = ValueNotifier<Duration>(
    Duration.zero,
  );

  final ValueNotifier<bool> running = ValueNotifier<bool>(false);

  DateTime? _runStart;
  Duration _baseElapsed = Duration.zero;
  bool _running = false;
  Timer? _timer;

  bool get isRunning => _running;

  void start() {
    _baseElapsed = Duration.zero;
    _runStart = now();
    _running = true;
    running.value = true;
    _startTimer();
    _tick();
  }

  void pause() {
    if (!_running || _runStart == null) return;
    _baseElapsed += now().difference(_runStart!);
    _runStart = null;
    _running = false;
    running.value = false;
    _stopTimer();
    elapsed.value = _baseElapsed;
  }

  void resume() {
    if (_running || _runStart != null) return;
    _runStart = now();
    _running = true;
    running.value = true;
    _startTimer();
    _tick();
  }

  void stop() {
    if (_running && _runStart != null) {
      _baseElapsed += now().difference(_runStart!);
      _runStart = null;
      _running = false;
      running.value = false;
    }
    _stopTimer();
    elapsed.value = _baseElapsed;
  }

  void dispose() {
    _stopTimer();
    elapsed.dispose();
    running.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    if (!_running || _runStart == null) {
      elapsed.value = _baseElapsed;
      return;
    }
    elapsed.value = _baseElapsed + now().difference(_runStart!);
  }
}
