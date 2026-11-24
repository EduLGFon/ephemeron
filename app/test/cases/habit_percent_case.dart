import 'package:ephemeron/domain/habits/habit_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fractional minute progress shows percentage of goal', () {
    expect(
      formatHabitProgress(unit: 'min', amount: 12.5, goal: 30),
      '41.7% of 30 min',
    );
  });

  test('whole minute progress keeps exact amount', () {
    expect(formatHabitProgress(unit: 'min', amount: 10, goal: 30), '10/30 min');
  });

  test('percent formatting keeps one decimal and does not clamp', () {
    expect(formatHabitPercent(amount: 12.5, goal: 30), '41.7%');
    expect(formatHabitPercent(amount: 12, goal: 10), '120.0%');
    expect(formatHabitPercent(amount: 0.01, goal: 10), '0.1%');
  });

  test('exact tooltip formats minutes and seconds', () {
    expect(
      formatHabitExact(unit: 'min', amount: 12.5, goal: 30),
      '12m 30s / 30 min',
    );
    expect(
      formatHabitExact(unit: 'min', amount: 61 / 60, goal: 30),
      '1m 1s / 30 min',
    );
  });

  test('formatHabitAmount zero minutes returns 0 min', () {
    expect(formatHabitAmount(unit: 'min', amount: 0), '0 min');
    expect(formatHabitAmount(unit: 'min', amount: 0.5), '30s');
    expect(formatHabitAmount(unit: 'min', amount: 2), '2 min');
  });

  test('non-minute units are unchanged', () {
    expect(
      formatHabitProgress(unit: 'count', amount: 12.333333, goal: 30),
      '12.333333/30 count',
    );
  });

  test('live amount adds focus and stopwatch time for a linked habit', () {
    const start = 1000000;
    const now = start + 5 * 60000;
    for (final phase in ['focus', 'stopwatch']) {
      expect(
        liveHabitAmount(
          habitId: 'h1',
          selectedDayKey: '2026-03-01',
          todayKey: '2026-03-01',
          unit: 'min',
          loggedAmount: 1,
          sessionHabitId: 'h1',
          sessionPhase: phase,
          sessionStartUtcMs: start,
          nowMs: now,
        ),
        6,
      );
    }
  });

  test('live amount excludes breaks, other habits, past days and units', () {
    const start = 1000000;
    const now = start + 5 * 60000;
    double live({
      String selectedDayKey = '2026-03-01',
      String? unit = 'min',
      String? sessionHabitId = 'h1',
      String? sessionPhase = 'focus',
    }) {
      return liveHabitAmount(
        habitId: 'h1',
        selectedDayKey: selectedDayKey,
        todayKey: '2026-03-01',
        unit: unit,
        loggedAmount: 2,
        sessionHabitId: sessionHabitId,
        sessionPhase: sessionPhase,
        sessionStartUtcMs: start,
        nowMs: now,
      );
    }

    expect(live(sessionPhase: 'break'), 2);
    expect(live(sessionPhase: null), 2);
    expect(live(sessionHabitId: 'h2'), 2);
    expect(live(sessionHabitId: null), 2);
    expect(live(selectedDayKey: '2026-02-28'), 2);
    expect(live(unit: 'count'), 2);
    expect(live(), 7);
  });
}
