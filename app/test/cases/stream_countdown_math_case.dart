import 'package:ephemeron/features/stream/presentation/countdowns/countdown_landmark_item.dart';
import 'package:ephemeron/features/stream/presentation/countdowns/countdown_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int utcDays(int y1, int m1, int d1, int y2, int m2, int d2) {
    return DateTime.utc(y2, m2, d2).difference(DateTime.utc(y1, m1, d1)).inDays;
  }

  test('calendar-day difference, today', () {
    final item = CountdownLandmarkItem(
      id: 'a',
      title: 'A',
      targetDayKey: '2026-03-10',
    );
    final now = DateTime(2026, 3, 10, 14, 30);
    expect(daysUntil(item, now), 0);
    expect(countdownLandmarkKind(item, now), CountdownLandmarkKind.today);
  });

  test('past', () {
    final item = CountdownLandmarkItem(
      id: 'b',
      title: 'B',
      targetDayKey: '2026-03-08',
    );
    final now = DateTime(2026, 3, 10);
    expect(daysUntil(item, now), -2);
    expect(countdownLandmarkKind(item, now), CountdownLandmarkKind.past);
  });

  test('future', () {
    final item = CountdownLandmarkItem(
      id: 'c',
      title: 'C',
      targetDayKey: '2026-03-15',
    );
    final now = DateTime(2026, 3, 10);
    expect(daysUntil(item, now), 5);
    expect(countdownLandmarkKind(item, now), CountdownLandmarkKind.future);
  });

  test('far future', () {
    final item = CountdownLandmarkItem(
      id: 'd',
      title: 'D',
      targetDayKey: '2030-01-01',
    );
    final now = DateTime(2026, 3, 10);
    expect(daysUntil(item, now), greaterThan(1000));
  });

  test('spring-forward interval is 1 day in any TZ', () {
    final item = CountdownLandmarkItem(
      id: 'e',
      title: 'E',
      targetDayKey: '2026-03-09',
    );
    final now = DateTime(2026, 3, 8, 23, 30);
    expect(daysUntil(item, now), 1);
    expect(utcDays(2026, 3, 8, 2026, 3, 9), 1);
  });

  test('targetMs path', () {
    final ms = DateTime(2026, 3, 12).millisecondsSinceEpoch;
    final item = CountdownLandmarkItem(id: 'f', title: 'F', targetMs: ms);
    final now = DateTime(2026, 3, 10);
    expect(daysUntil(item, now), 2);
  });

  test('invalid day key returns null/invalid', () {
    for (final key in ['not-a-date', '2026-13-01', '2026-02-30']) {
      final item = CountdownLandmarkItem(
        id: 'g',
        title: 'G',
        targetDayKey: key,
      );
      final now = DateTime(2026, 3, 10);
      expect(daysUntil(item, now), isNull);
      expect(countdownLandmarkKind(item, now), CountdownLandmarkKind.invalid);
    }
  });

  test('missing target returns null/invalid', () {
    final item = CountdownLandmarkItem(id: 'h', title: 'H');
    final now = DateTime(2026, 3, 10);
    expect(daysUntil(item, now), isNull);
    expect(countdownLandmarkKind(item, now), CountdownLandmarkKind.invalid);
  });
}
