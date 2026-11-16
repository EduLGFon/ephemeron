// Pure domain logic for habit compliance statistics (no Flutter/Drift).
//
// A habit with a positive goal is scored by weighted goal compliance over
// scheduled past days; binary habits (no goal) are scored by done days.
// Skipped days are neutral and excluded from the denominator. Future days and
// days before the habit start date are excluded. Today is excluded from the
// compliance windows because it is still in progress; per-day deficits for
// today are still reported for catch-up.
import 'date_key.dart';
import 'streaks.dart';

/// One day's habit log in domain form (no Drift dependency).
class HabitLogEntry {
  const HabitLogEntry({
    required this.dayKey,
    this.amount = 0,
    this.done = false,
    this.skipped = false,
  });

  final String dayKey;
  final double amount;
  final bool done;
  final bool skipped;
}

enum HabitDayOutcome { perfect, partial, missed }

class HabitDayProgress {
  const HabitDayProgress({
    required this.dayKey,
    required this.outcome,
    required this.amount,
    required this.goal,
    required this.missing,
  });

  final String dayKey;
  final HabitDayOutcome outcome;
  final double amount;
  final double goal;
  final double missing;
}

class WeeklyTargetProgress {
  const WeeklyTargetProgress({required this.done, required this.target});

  final int done;
  final int target;

  bool get met => done >= target;

  double get ratio => target <= 0 ? 0.0 : (done / target).clamp(0.0, 1.0);
}

class HabitStatsSummary {
  const HabitStatsSummary({
    required this.hasGoal,
    required this.goal,
    required this.unit,
    required this.compliance7,
    required this.compliance30,
    required this.perfectDays,
    required this.partialDays,
    required this.missedDays,
    required this.skippedDays,
    required this.scoredDays,
    required this.totalLogged,
    required this.totalGoal,
    required this.deficit,
    required this.currentStreak,
    required this.bestStreak,
    required this.catchUpDays,
    this.weekly,
    required this.rangeDays,
  });

  final bool hasGoal;
  final double goal;
  final String? unit;
  final double compliance7;
  final double compliance30;
  final int perfectDays;
  final int partialDays;
  final int missedDays;
  final int skippedDays;
  final int scoredDays;
  final double totalLogged;
  final double totalGoal;
  final double deficit;
  final int currentStreak;
  final int bestStreak;
  final List<HabitDayProgress> catchUpDays;
  final WeeklyTargetProgress? weekly;
  final int rangeDays;

  bool get binary => !hasGoal;
}

class _DayResult {
  _DayResult({
    required this.dayKey,
    required this.skipped,
    required this.credit,
    required this.goal,
    required this.outcome,
  });

  final String dayKey;
  final bool skipped;
  final double credit;
  final double goal;
  final HabitDayOutcome outcome;
}

class _Agg {
  double amount = 0;
  bool done = false;
  bool skipped = false;
}

HabitStatsSummary computeHabitStats({
  required String todayKey,
  required HabitSpec spec,
  required String? unit,
  required double? goalAmount,
  required Iterable<HabitLogEntry> logs,
  int rangeDays = 30,
  int recentDays = 7,
}) {
  final today = parseKey(todayKey);
  final goal = (goalAmount == null || goalAmount <= 0) ? 0.0 : goalAmount;
  final hasGoal = goal > 0;

  final byDay = <String, _Agg>{};
  for (final log in logs) {
    if (log.dayKey.isEmpty) continue;
    final cur = byDay.putIfAbsent(log.dayKey, _Agg.new);
    if (log.amount > cur.amount) cur.amount = log.amount;
    cur.done = cur.done || log.done;
    cur.skipped = cur.skipped || log.skipped;
  }

  bool isDone(String dayKey) {
    final log = byDay[dayKey];
    if (log == null) return false;
    if (log.done) return true;
    return hasGoal && log.amount >= goal;
  }

  bool isSkipped(String dayKey) => byDay[dayKey]?.skipped ?? false;

  final window = rangeDays < 1 ? 1 : rangeDays;
  final scoringWindow = window > 30 ? window : 30;
  final earliestStart = DateTime(
    today.year,
    today.month,
    today.day - scoringWindow,
  );
  final startDate = spec.startDate == null ? null : parseKey(spec.startDate!);
  final effectiveStart = (startDate != null && startDate.isAfter(earliestStart))
      ? startDate
      : earliestStart;

  double creditFor(_Agg? log) {
    if (!hasGoal) return 0;
    if (log == null) return 0;
    if (log.done && log.amount <= 0) return goal;
    final amt = log.amount < 0 ? 0.0 : log.amount;
    return amt > goal ? goal : amt;
  }

  final results = <_DayResult>[];
  var cur = effectiveStart;
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  while (!cur.isAfter(yesterday)) {
    if (isHabitScheduled(spec, cur)) {
      final key = habitDateKey(cur);
      final log = byDay[key];
      final skipped = log?.skipped ?? false;
      if (skipped) {
        results.add(
          _DayResult(
            dayKey: key,
            skipped: true,
            credit: 0,
            goal: goal,
            outcome: HabitDayOutcome.missed,
          ),
        );
      } else {
        final credit = creditFor(log);
        final outcome = !hasGoal
            ? (log?.done == true
                  ? HabitDayOutcome.perfect
                  : HabitDayOutcome.missed)
            : (credit >= goal && credit > 0
                  ? HabitDayOutcome.perfect
                  : (credit > 0
                        ? HabitDayOutcome.partial
                        : HabitDayOutcome.missed));
        results.add(
          _DayResult(
            dayKey: key,
            skipped: false,
            credit: credit,
            goal: goal,
            outcome: outcome,
          ),
        );
      }
    }
    cur = DateTime(cur.year, cur.month, cur.day + 1);
  }

  int perfectDays = 0, partialDays = 0, missedDays = 0, skippedDays = 0;
  double totalLogged = 0, totalGoal = 0, totalDeficit = 0;
  int scoredDays = 0;

  final last7StartKey = habitDateKey(
    DateTime(today.year, today.month, today.day - 7),
  );
  final last30StartKey = habitDateKey(
    DateTime(today.year, today.month, today.day - 30),
  );

  final compliance7Days = <_DayResult>[];
  final compliance30Days = <_DayResult>[];
  final windowStartKey = habitDateKey(
    DateTime(today.year, today.month, today.day - window),
  );

  for (final r in results) {
    final inWindow = r.dayKey.compareTo(windowStartKey) >= 0;
    final in7 = r.dayKey.compareTo(last7StartKey) >= 0;
    final in30 = r.dayKey.compareTo(last30StartKey) >= 0;

    if (r.skipped) {
      if (inWindow) skippedDays++;
      if (in7) compliance7Days.add(r);
      if (in30) compliance30Days.add(r);
      continue;
    }
    if (in7) compliance7Days.add(r);
    if (in30) compliance30Days.add(r);
    if (!inWindow) continue;
    scoredDays++;
    switch (r.outcome) {
      case HabitDayOutcome.perfect:
        perfectDays++;
        break;
      case HabitDayOutcome.partial:
        partialDays++;
        break;
      case HabitDayOutcome.missed:
        missedDays++;
        break;
    }
    totalLogged += r.credit;
    totalGoal += r.goal;
    if (hasGoal) {
      final d = r.goal - r.credit;
      if (d > 0) totalDeficit += d;
    }
  }

  double complianceOf(List<_DayResult> days) {
    if (days.isEmpty) return 0.0;
    if (!hasGoal) {
      final done = days
          .where((d) => d.outcome == HabitDayOutcome.perfect)
          .length;
      return (done / days.length).clamp(0.0, 1.0);
    }
    var credit = 0.0, target = 0.0;
    for (final d in days) {
      if (d.skipped) continue;
      credit += d.credit;
      target += d.goal;
    }
    if (target <= 0) return 0.0;
    return (credit / target).clamp(0.0, 1.0);
  }

  final compliance7 = complianceOf(compliance7Days);
  final compliance30 = complianceOf(compliance30Days);

  // Catch-up entries: today + recent past scheduled days with a deficit.
  final catchUp = <HabitDayProgress>[];
  final recent = recentDays < 1 ? 1 : recentDays;
  for (var i = 0; i <= recent; i++) {
    final day = DateTime(today.year, today.month, today.day - i);
    if (!isHabitScheduled(spec, day)) continue;
    final key = habitDateKey(day);
    final log = byDay[key];
    final skipped = log?.skipped ?? false;
    if (skipped) continue;
    if (!hasGoal) continue;
    final credit = creditFor(log);
    final missing = goal - credit;
    if (missing <= 0) continue;
    final outcome = credit >= goal && credit > 0
        ? HabitDayOutcome.perfect
        : (credit > 0 ? HabitDayOutcome.partial : HabitDayOutcome.missed);
    catchUp.add(
      HabitDayProgress(
        dayKey: key,
        outcome: outcome,
        amount: credit,
        goal: goal,
        missing: missing,
      ),
    );
  }

  // Weekly-target progress for the current week.
  WeeklyTargetProgress? weekly;
  if (spec.frequency == 'weekly') {
    final target = spec.weeklyTarget < 1 ? 1 : spec.weeklyTarget;
    final monday = DateTime(
      today.year,
      today.month,
      today.day - ((today.weekday - 1) % 7),
    );
    var done = 0;
    for (var i = 0; i < 7; i++) {
      final d = DateTime(monday.year, monday.month, monday.day + i);
      if (!isHabitScheduled(spec, d)) continue;
      if (isDone(habitDateKey(d))) done++;
    }
    weekly = WeeklyTargetProgress(done: done, target: target);
  }

  final streaks = currentStreak(spec, todayKey, isDone, isSkipped);
  // bestStreak is the historical best; compute via helper.
  final best = bestStreak(spec, todayKey, isDone, isSkipped);

  return HabitStatsSummary(
    hasGoal: hasGoal,
    goal: goal,
    unit: unit,
    compliance7: compliance7,
    compliance30: compliance30,
    perfectDays: perfectDays,
    partialDays: partialDays,
    missedDays: missedDays,
    skippedDays: skippedDays,
    scoredDays: scoredDays,
    totalLogged: totalLogged,
    totalGoal: totalGoal,
    deficit: totalDeficit,
    currentStreak: streaks,
    bestStreak: best,
    catchUpDays: catchUp,
    weekly: weekly,
    rangeDays: window,
  );
}

String formatCompliancePercent(double ratio) {
  final pct = (ratio.clamp(0.0, 1.0) * 100).round();
  return '$pct%';
}
