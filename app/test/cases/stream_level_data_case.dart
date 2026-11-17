import 'package:ephemeron/features/stream/presentation/levels/level_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Berlin DST week yields 7 days', () {
    // Berlin springs forward Mar 29 2026; Mar 26 .. Apr 1.
    final start = DateTime(2026, 3, 26);
    final end = DateTime(2026, 4, 1);
    final result = LevelData.countsForRange(
      rangeStart: start,
      rangeEnd: end,
      marks: const [],
    );
    expect(result.length, 7);
  });

  test('Sunday-first and Monday-first week lengths', () {
    // countsForRange is date-based; just ensure 7 days for a normal week.
    final r1 = LevelData.countsForRange(
      rangeStart: DateTime(2026, 1, 4), // Sunday
      rangeEnd: DateTime(2026, 1, 10), // Saturday
      marks: const [],
    );
    expect(r1.length, 7);
    final r2 = LevelData.countsForRange(
      rangeStart: DateTime(2026, 1, 5), // Monday
      rangeEnd: DateTime(2026, 1, 11), // Sunday
      marks: const [],
    );
    expect(r2.length, 7);
  });
}
