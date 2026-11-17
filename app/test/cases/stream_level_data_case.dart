import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:ephemeron/features/stream/application/stream_level_data.dart';
import 'package:ephemeron/features/stream/presentation/levels/level_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedBuiltRange extends CalendarBuiltRange {
  _FixedBuiltRange(this._range);

  final CalendarRange? _range;

  @override
  CalendarRange? build() => _range;
}

CalendarRange _novemberCache() => CalendarRange(
  fromUtc: DateTime.utc(2026, 11, 1),
  toUtc: DateTime.utc(2026, 12, 1),
);

OccurrenceCacheData _row({
  required String id,
  required DateTime localStart,
  Duration duration = const Duration(hours: 1),
  String? dayKey,
}) {
  final startUtc = localStart.toUtc();
  final endUtc = startUtc.add(duration);
  return OccurrenceCacheData(
    id: id,
    eventId: 'e-$id',
    title: id,
    startUtc: startUtc.millisecondsSinceEpoch,
    endUtc: endUtc.millisecondsSinceEpoch,
    dayKey: dayKey ?? '2026-11-17',
    sourceType: 'event',
  );
}

OccurrenceCacheData _invalidRow(String id) => OccurrenceCacheData(
  id: id,
  eventId: '',
  startUtc: DateTime.utc(2026, 11, 17, 15).millisecondsSinceEpoch,
  endUtc: DateTime.utc(2026, 11, 17, 16).millisecondsSinceEpoch,
  dayKey: '2026-11-17',
  sourceType: 'event',
);

ProviderContainer _container({
  required CalendarRange? built,
  required StreamLevelRange range,
  required List<OccurrenceCacheData> rows,
}) {
  return ProviderContainer(
    overrides: [
      calendarBuiltRangeProvider.overrideWith(() => _FixedBuiltRange(built)),
      windowOccurrencesProvider(streamLevelQueryRange(range))
          .overrideWithValue(AsyncData(rows)),
    ],
  );
}

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

  group('streamWeekStart', () {
    test('Monday-first week', () {
      expect(streamWeekStart(DateTime(2026, 11, 18)), DateTime(2026, 11, 16));
    });

    test('Sunday-first week', () {
      expect(
        streamWeekStart(
          DateTime(2026, 11, 18),
          firstDayOfWeek: DateTime.sunday,
        ),
        DateTime(2026, 11, 15),
      );
    });

    test('week crossing a month boundary', () {
      expect(streamWeekStart(DateTime(2026, 12, 31)), DateTime(2026, 12, 28));
      expect(
        streamWeekStart(DateTime(2026, 1, 1), firstDayOfWeek: DateTime.sunday),
        DateTime(2025, 12, 28),
      );
    });

    test('DST transition week stays a local calendar week', () {
      // America/New_York springs forward on 2026-03-08.
      final range = streamLevelRangeFor(StreamLevel.week, DateTime(2026, 3, 8));
      expect(range.level, StreamLevel.week);
      expect(range.start, DateTime(2026, 3, 2));
      expect(range.end, DateTime(2026, 3, 9));
      final spansDst =
          DateTime(2026, 3, 2).timeZoneOffset !=
          DateTime(2026, 3, 9).timeZoneOffset;
      // Adding 7 * 24h would land on 01:00 the next day in a DST zone.
      expect(range.end.difference(range.start).inHours, spansDst ? 167 : 168);
    });
  });

  group('streamMonthRange', () {
    test('28, 30 and 31 day months', () {
      expect(streamMonthRange(DateTime(2026, 2, 15)).end, DateTime(2026, 3, 1));
      expect(streamMonthRange(DateTime(2026, 4, 10)).end, DateTime(2026, 5, 1));
      expect(streamMonthRange(DateTime(2026, 1, 31)).end, DateTime(2026, 2, 1));
    });

    test('December rolls into January', () {
      final range = streamMonthRange(DateTime(2026, 12, 20));
      expect(range.start, DateTime(2026, 12, 1));
      expect(range.end, DateTime(2027, 1, 1));
    });

    test('month level dispatch matches streamMonthRange', () {
      final date = DateTime(2026, 2, 15);
      expect(
        streamLevelRangeFor(StreamLevel.month, date),
        streamMonthRange(date),
      );
    });
  });

  group('streamLevelMarksProvider', () {
    // Local week 2026-11-16 .. 2026-11-23.
    final week = streamLevelRangeFor(StreamLevel.week, DateTime(2026, 11, 18));

    test('covered range maps and filters marks to the local range', () async {
      final container = _container(
        built: _novemberCache(),
        range: week,
        rows: [
          _row(id: 'inside', localStart: DateTime(2026, 11, 17, 10)),
          _row(id: 'outside', localStart: DateTime(2026, 11, 25, 10)),
          _row(
            id: 'all-day',
            localStart: DateTime.utc(2026, 11, 19),
            duration: const Duration(hours: 24),
            dayKey: '2026-11-19',
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        streamLevelMarksProvider(week).future,
      );
      expect(result.covered, isTrue);
      expect(result.marks.map((m) => m.id), ['inside', 'all-day']);
      expect(result.skipped, 0);
    });

    test('uncovered range returns empty with covered false', () async {
      final container = ProviderContainer(
        overrides: [
          calendarBuiltRangeProvider.overrideWith(
            () => _FixedBuiltRange(
              CalendarRange(
                fromUtc: DateTime.utc(2026, 11, 18),
                toUtc: DateTime.utc(2026, 11, 20),
              ),
            ),
          ),
          windowOccurrencesProvider(streamLevelQueryRange(week))
              .overrideWithValue(const AsyncData(<OccurrenceCacheData>[])),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        streamLevelMarksProvider(week).future,
      );
      expect(result.covered, isFalse);
      expect(result.marks, isEmpty);
      expect(result.skipped, 0);
    });

    test('invalid rows are counted as skipped', () async {
      final container = _container(
        built: _novemberCache(),
        range: week,
        rows: [
          _row(id: 'ok', localStart: DateTime(2026, 11, 17, 9)),
          _invalidRow('bad'),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        streamLevelMarksProvider(week).future,
      );
      expect(result.marks.map((m) => m.id), ['ok']);
      expect(result.skipped, 1);
    });

    test('empty range yields no marks', () async {
      final container = _container(
        built: _novemberCache(),
        range: week,
        rows: const <OccurrenceCacheData>[],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        streamLevelMarksProvider(week).future,
      );
      expect(result.covered, isTrue);
      expect(result.marks, isEmpty);
      expect(result.skipped, 0);
    });

    test('5000 rows map without a quadratic path', () async {
      final rows = List<OccurrenceCacheData>.generate(5000, (i) {
        final start = DateTime(2026, 11, 16).add(Duration(minutes: i));
        return _row(id: 'r$i', localStart: start);
      });
      final container = _container(
        built: _novemberCache(),
        range: week,
        rows: rows,
      );
      addTearDown(container.dispose);

      final result = await container.read(
        streamLevelMarksProvider(week).future,
      );
      expect(result.marks.length, 5000);
      expect(result.skipped, 0);
    });
  });
}
