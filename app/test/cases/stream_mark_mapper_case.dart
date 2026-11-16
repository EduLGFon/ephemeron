import 'package:flutter_test/flutter_test.dart';

import 'package:ephemeron/features/stream/application/stream_mark.dart';
import 'package:ephemeron/features/stream/application/stream_mark_mapper.dart';

void main() {
  group('mapOccurrencesToMarks', () {
    test('timed event maps and converts to local ms', () {
      final baseUtc = DateTime.utc(2025, 1, 15, 10, 0);
      final endUtc = baseUtc.add(const Duration(hours: 1));
      final result = mapOccurrencesToMarks([
        OccurrenceRow(
          id: 'o1',
          eventId: 'e1',
          sourceType: 'event',
          startUtc: baseUtc.millisecondsSinceEpoch,
          endUtc: endUtc.millisecondsSinceEpoch,
          dayKey: '2025-01-15',
          title: 'Meeting',
          colorId: '7',
        ),
      ]);
      expect(result.skipped, 0);
      expect(result.marks.length, 1);
      final m = result.marks.first;
      expect(m.id, 'o1');
      expect(m.kind, StreamMarkKind.event);
      expect(m.title, 'Meeting');
      expect(m.sourceTaskOrEventId, 'e1');
      expect(m.isAllDay, false);
      final expectedStart = baseUtc.toLocal().millisecondsSinceEpoch;
      final expectedEnd = endUtc.toLocal().millisecondsSinceEpoch;
      expect(m.startMs, expectedStart);
      expect(m.endMs, expectedEnd);
    });

    test('all-day occurrence uses local midnight span', () {
      final baseUtc = DateTime.utc(2025, 1, 15, 0, 0);
      final endUtc = baseUtc.add(const Duration(hours: 24));
      final result = mapOccurrencesToMarks([
        OccurrenceRow(
          id: 'o2',
          eventId: 'e2',
          sourceType: 'event',
          startUtc: baseUtc.millisecondsSinceEpoch,
          endUtc: endUtc.millisecondsSinceEpoch,
          dayKey: '2025-01-15',
          title: 'Holiday',
        ),
      ]);
      expect(result.skipped, 0);
      final m = result.marks.first;
      expect(m.isAllDay, true);
      final local = baseUtc.toLocal();
      final midnight = DateTime(local.year, local.month, local.day);
      expect(m.startMs, midnight.millisecondsSinceEpoch);
      expect(
        m.endMs,
        midnight.add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
    });

    test('zero duration gets minimum visible length', () {
      final baseUtc = DateTime.utc(2025, 1, 15, 10, 0);
      final result = mapOccurrencesToMarks([
        OccurrenceRow(
          id: 'o3',
          eventId: 'e3',
          sourceType: 'task',
          startUtc: baseUtc.millisecondsSinceEpoch,
          endUtc: baseUtc.millisecondsSinceEpoch,
          dayKey: '2025-01-15',
          title: 'Task',
        ),
      ]);
      final m = result.marks.first;
      expect(m.kind, StreamMarkKind.task);
      expect(m.endMs - m.startMs, 15 * 60 * 1000);
    });

    test('negative duration gets minimum visible length', () {
      final baseUtc = DateTime.utc(2025, 1, 15, 10, 0);
      final result = mapOccurrencesToMarks([
        OccurrenceRow(
          id: 'o4',
          eventId: 'e4',
          sourceType: 'event',
          startUtc: baseUtc.millisecondsSinceEpoch,
          endUtc: baseUtc.millisecondsSinceEpoch - 1000,
          dayKey: '2025-01-15',
          title: 'Bad',
        ),
      ]);
      final m = result.marks.first;
      expect(m.endMs - m.startMs, 15 * 60 * 1000);
    });

    test('empty title kept as given (empty)', () {
      final baseUtc = DateTime.utc(2025, 1, 15, 10, 0);
      final result = mapOccurrencesToMarks([
        OccurrenceRow(
          id: 'o5',
          eventId: 'e5',
          sourceType: 'event',
          startUtc: baseUtc.millisecondsSinceEpoch,
          endUtc: baseUtc
              .add(const Duration(minutes: 30))
              .millisecondsSinceEpoch,
          dayKey: '2025-01-15',
          title: null,
        ),
      ]);
      expect(result.marks.first.title, '');
    });

    test('unsorted input is sorted by startMs', () {
      final a = DateTime.utc(2025, 1, 15, 12, 0);
      final b = DateTime.utc(2025, 1, 15, 9, 0);
      final result = mapOccurrencesToMarks([
        OccurrenceRow(
          id: 'late',
          eventId: 'e',
          sourceType: 'event',
          startUtc: a.millisecondsSinceEpoch,
          endUtc: a.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
          dayKey: '2025-01-15',
          title: 'late',
        ),
        OccurrenceRow(
          id: 'early',
          eventId: 'e',
          sourceType: 'event',
          startUtc: b.millisecondsSinceEpoch,
          endUtc: b.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
          dayKey: '2025-01-15',
          title: 'early',
        ),
      ]);
      expect(result.marks.map((m) => m.id).toList(), ['early', 'late']);
    });

    test('malformed row is skipped and counted', () {
      final baseUtc = DateTime.utc(2025, 1, 15, 10, 0);
      final result = mapOccurrencesToMarks([
        OccurrenceRow(
          id: '',
          eventId: 'e',
          sourceType: 'event',
          startUtc: baseUtc.millisecondsSinceEpoch,
          endUtc: baseUtc
              .add(const Duration(minutes: 10))
              .millisecondsSinceEpoch,
          dayKey: '2025-01-15',
          title: 'bad',
        ),
        OccurrenceRow(
          id: 'ok',
          eventId: 'e',
          sourceType: 'event',
          startUtc: baseUtc.millisecondsSinceEpoch,
          endUtc: baseUtc
              .add(const Duration(minutes: 10))
              .millisecondsSinceEpoch,
          dayKey: '2025-01-15',
          title: 'good',
        ),
      ]);
      expect(result.skipped, 1);
      expect(result.marks.length, 1);
      expect(result.marks.first.id, 'ok');
    });
  });
}
