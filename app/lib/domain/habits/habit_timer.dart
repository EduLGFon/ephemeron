// Pure helpers for habit stopwatch timers (no Flutter/Riverpod dependencies).
bool isMinuteUnit(String? unit) {
  if (unit == null) return false;
  final u = unit.trim().toLowerCase();
  return u == 'min' || u == 'mins' || u == 'minute' || u == 'minutes';
}

Duration timerElapsed({required int startedAtMs, required int nowMs}) {
  final ms = nowMs - startedAtMs;
  if (ms < 0) return Duration.zero;
  return Duration(milliseconds: ms);
}

double elapsedMinutes(Duration elapsed) => elapsed.inSeconds / 60.0;

String formatElapsed(Duration elapsed) {
  final totalSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final hh = hours.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
  return '$mm:$ss';
}

String _fmtNumber(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

/// Goal percentage with one decimal. Not clamped: overfill is meaningful
/// (for example 12/10 shows 120.0%).
String formatHabitPercent({required double amount, required double goal}) {
  final pct = goal > 0 ? amount / goal * 100 : 0.0;
  return '${pct.toStringAsFixed(1)}%';
}

String formatHabitProgress({
  required String? unit,
  required double amount,
  required double goal,
}) {
  final u = unit ?? '';
  if (isMinuteUnit(unit) && amount != amount.roundToDouble()) {
    return '${formatHabitPercent(amount: amount, goal: goal)} '
            'of ${_fmtNumber(goal)} $u'
        .trim();
  }
  return '${_fmtNumber(amount)}/${_fmtNumber(goal)} $u'.trim();
}

/// Whether a running focus session adds live progress to [habitId] on the
/// selected day. Only focus and stopwatch phases count; breaks and other
/// habits never do. Live minutes only make sense for minute-unit habits.
bool isLiveHabitProgress({
  required String habitId,
  required String selectedDayKey,
  required String todayKey,
  required String? unit,
  required String? sessionHabitId,
  required String? sessionPhase,
}) {
  if (!isMinuteUnit(unit)) return false;
  if (selectedDayKey != todayKey) return false;
  if (sessionHabitId != habitId) return false;
  return sessionPhase == 'focus' || sessionPhase == 'stopwatch';
}

/// Live habit amount in the habit's unit: [loggedAmount] plus the running
/// session's elapsed minutes when [isLiveHabitProgress] is true.
double liveHabitAmount({
  required String habitId,
  required String selectedDayKey,
  required String todayKey,
  required String? unit,
  required double loggedAmount,
  required String? sessionHabitId,
  required String? sessionPhase,
  required int? sessionStartUtcMs,
  required int nowMs,
}) {
  final live = isLiveHabitProgress(
    habitId: habitId,
    selectedDayKey: selectedDayKey,
    todayKey: todayKey,
    unit: unit,
    sessionHabitId: sessionHabitId,
    sessionPhase: sessionPhase,
  );
  if (!live || sessionStartUtcMs == null) return loggedAmount;
  final elapsedMs = nowMs - sessionStartUtcMs;
  if (elapsedMs <= 0) return loggedAmount;
  return loggedAmount + elapsedMs / 60000.0;
}

String formatHabitExact({
  required String? unit,
  required double amount,
  required double goal,
}) {
  final u = unit ?? '';
  if (isMinuteUnit(unit)) {
    final totalSeconds = (amount * 60).round();
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    String amountLabel;
    if (mins == 0) {
      amountLabel = '${secs}s';
    } else if (secs == 0) {
      amountLabel = '$mins min';
    } else {
      amountLabel = '${mins}m ${secs}s';
    }
    return '$amountLabel / ${_fmtNumber(goal)} $u'.trim();
  }
  return '${_fmtNumber(amount)}/${_fmtNumber(goal)} $u'.trim();
}

/// Formats a single amount (no goal) for compact UI labels such as catch-up
/// actions. Reuses the minute/second formatting of [formatHabitExact].
String formatHabitAmount({required String? unit, required double amount}) {
  final u = unit ?? '';
  if (isMinuteUnit(unit)) {
    final totalSeconds = (amount * 60).round();
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    if (mins == 0) {
      return '${secs}s'.trim();
    }
    if (secs == 0) {
      return '$mins min'.trim();
    }
    return '${mins}m ${secs}s'.trim();
  }
  return '${_fmtNumber(amount)} $u'.trim();
}
