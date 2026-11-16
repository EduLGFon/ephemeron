import 'package:ephemeron/domain/habits/habit_stats.dart';
import 'package:ephemeron/domain/habits/streaks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('3/5 min partial = 60% and deficit 2', () {
    final spec = HabitSpec(frequency: 'daily', startDate: '2026-03-09');
    final stats = computeHabitStats(
      todayKey: '2026-03-10',
      spec: spec,
      unit: 'min',
      goalAmount: 5,
      logs: const [HabitLogEntry(dayKey: '2026-03-09', amount: 3, done: false)],
      rangeDays: 7,
    );
    expect(stats.compliance7, closeTo(0.6, 1e-9));
    expect(stats.compliance30, closeTo(0.6, 1e-9));
    expect(stats.partialDays, 1);
    expect(stats.perfectDays, 0);
    expect(stats.missedDays, 0);
    expect(stats.deficit, closeTo(2, 1e-9));
    expect(stats.catchUpDays.length, 2);
    expect(
      stats.catchUpDays.firstWhere((d) => d.dayKey == '2026-03-09').missing,
      closeTo(2, 1e-9),
    );
    expect(formatCompliancePercent(stats.compliance7), '60%');
  });

  test('missed day counts as missed and lowers compliance', () {
    final spec = HabitSpec(frequency: 'daily');
    final stats = computeHabitStats(
      todayKey: '2026-03-10',
      spec: spec,
      unit: null,
      goalAmount: 5,
      logs: const [],
      rangeDays: 3,
    );
    // days 03-07,03-08,03-09 (3 scheduled past days), all missed
    expect(stats.scoredDays, 3);
    expect(stats.missedDays, 3);
    expect(stats.compliance30, 0.0);
    expect(stats.deficit, closeTo(15, 1e-9));
  });

  test('skipped days are neutral', () {
    final spec = HabitSpec(frequency: 'daily');
    final stats = computeHabitStats(
      todayKey: '2026-03-10',
      spec: spec,
      unit: 'min',
      goalAmount: 5,
      logs: const [
        HabitLogEntry(dayKey: '2026-03-09', amount: 5, done: true),
        HabitLogEntry(dayKey: '2026-03-08', skipped: true),
      ],
      rangeDays: 3,
    );
    expect(stats.skippedDays, 1);
    expect(stats.scoredDays, 2);
    expect(stats.perfectDays, 1);
    expect(stats.missedDays, 1);
    // only 03-07 missed
  });

  test('binary done/missed', () {
    final spec = HabitSpec(frequency: 'daily', startDate: '2026-03-07');
    final stats = computeHabitStats(
      todayKey: '2026-03-10',
      spec: spec,
      unit: null,
      goalAmount: null,
      logs: const [
        HabitLogEntry(dayKey: '2026-03-09', done: true),
        HabitLogEntry(dayKey: '2026-03-08', done: false),
      ],
      rangeDays: 3,
    );
    // 3 scheduled days: 03-07,03-08,03-09
    expect(stats.hasGoal, isFalse);
    expect(stats.perfectDays, 1);
    expect(stats.missedDays, 2);
    expect(stats.compliance30, closeTo(1 / 3, 1e-9));
  });

  test('weekly target progress', () {
    final spec = HabitSpec(frequency: 'weekly', weeklyTarget: 2);
    final stats = computeHabitStats(
      todayKey: '2026-03-10', // Tuesday
      spec: spec,
      unit: null,
      goalAmount: null,
      logs: const [
        HabitLogEntry(dayKey: '2026-03-09', done: true),
        HabitLogEntry(
          dayKey: '2026-03-10',
          done: true,
        ), // future? today excluded from windows but weekly counts all 7
      ],
      rangeDays: 7,
    );
    expect(stats.weekly, isNotNull);
    expect(stats.weekly!.target, 2);
    expect(stats.weekly!.done, greaterThanOrEqualTo(1));
  });

  test('range boundaries and start date', () {
    final spec = HabitSpec(frequency: 'daily', startDate: '2026-03-08');
    final stats = computeHabitStats(
      todayKey: '2026-03-10',
      spec: spec,
      unit: 'min',
      goalAmount: 5,
      logs: const [],
      rangeDays: 7,
    );
    // only 03-08, 03-09 (start date respected)
    expect(stats.scoredDays, 2);
  });

  test('future days excluded', () {
    final spec = HabitSpec(frequency: 'daily');
    final stats = computeHabitStats(
      todayKey: '2026-03-10',
      spec: spec,
      unit: 'min',
      goalAmount: 5,
      logs: const [HabitLogEntry(dayKey: '2026-03-11', amount: 5, done: true)],
      rangeDays: 7,
    );
    // future day not in windows
    expect(stats.perfectDays, 0);
    expect(stats.scoredDays, 7);
  });

  test('overfill capped at 100%', () {
    final spec = HabitSpec(frequency: 'daily', startDate: '2026-03-09');
    final stats = computeHabitStats(
      todayKey: '2026-03-10',
      spec: spec,
      unit: 'min',
      goalAmount: 5,
      logs: const [HabitLogEntry(dayKey: '2026-03-09', amount: 10, done: true)],
      rangeDays: 7,
    );
    expect(stats.compliance30, 1.0);
    expect(formatCompliancePercent(stats.compliance30), '100%');
    expect(stats.deficit, 0);
  });

  test('done with absent amount counts goal', () {
    final spec = HabitSpec(frequency: 'daily', startDate: '2026-03-09');
    final stats = computeHabitStats(
      todayKey: '2026-03-10',
      spec: spec,
      unit: 'min',
      goalAmount: 5,
      logs: const [HabitLogEntry(dayKey: '2026-03-09', amount: 0, done: true)],
      rangeDays: 7,
    );
    expect(stats.perfectDays, 1);
    expect(stats.compliance30, 1.0);
  });

  test('done with below-goal amount counts proportionally', () {
    final spec = HabitSpec(frequency: 'daily', startDate: '2026-03-09');
    final stats = computeHabitStats(
      todayKey: '2026-03-10',
      spec: spec,
      unit: 'min',
      goalAmount: 5,
      logs: const [HabitLogEntry(dayKey: '2026-03-09', amount: 3, done: true)],
      rangeDays: 7,
    );
    expect(stats.partialDays, 1);
    expect(stats.compliance30, closeTo(0.6, 1e-9));
  });
}
