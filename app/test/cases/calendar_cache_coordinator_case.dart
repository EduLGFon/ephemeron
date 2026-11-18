// Calendar cache coordinator: single-flight rebuilds and coverage tracking.
import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/features/calendar/application/calendar_cache_coordinator.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/application/calendar_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

CalendarRange _range(int fromDay, int toDay) => CalendarRange(
  fromUtc: DateTime.utc(2026, 3, fromDay),
  toUtc: DateTime.utc(2026, 3, toDay),
);

class _CountingOccurrenceRepository extends OccurrenceRepository {
  _CountingOccurrenceRepository(super.db);

  final List<CalendarRange> rebuilds = [];
  Completer<void>? gate;
  Object? failNext;
  bool materialize = false;
  int _active = 0;
  int maxConcurrent = 0;

  @override
  Future<int> rebuildWindow({
    required DateTime windowStartUtc,
    required DateTime windowEndUtc,
  }) async {
    _active++;
    if (_active > maxConcurrent) maxConcurrent = _active;
    try {
      final failure = failNext;
      if (failure != null) {
        failNext = null;
        throw failure;
      }
      rebuilds.add(CalendarRange(fromUtc: windowStartUtc, toUtc: windowEndUtc));
      final pending = gate;
      if (pending != null) await pending.future;
      if (!materialize) return 0;
      return await super.rebuildWindow(
        windowStartUtc: windowStartUtc,
        windowEndUtc: windowEndUtc,
      );
    } finally {
      _active--;
    }
  }
}

void main() {
  test('concurrent ensureRange calls coalesce into one rebuild', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = _CountingOccurrenceRepository(db);
    final coordinator = CalendarCacheCoordinator(repo);
    final gate = Completer<void>();
    repo.gate = gate;
    final range = _range(1, 10);

    final first = coordinator.ensureRange(range);
    await Future<void>.delayed(Duration.zero);
    final second = coordinator.ensureRange(_range(3, 5));
    await Future<void>.delayed(Duration.zero);
    expect(repo.rebuilds, hasLength(1));

    gate.complete();
    await Future.wait([first, second]);

    expect(repo.rebuilds, hasLength(1));
    expect(repo.maxConcurrent, 1);
    expect(coordinator.builtRange, range);
  });

  test('a wider built range covers later narrower requests', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = _CountingOccurrenceRepository(db);
    final coordinator = CalendarCacheCoordinator(repo);
    final wide = _range(1, 20);

    await coordinator.ensureRange(wide);
    await coordinator.ensureRange(_range(5, 10));
    await coordinator.ensureRange(wide);

    expect(repo.rebuilds, hasLength(1));
    expect(repo.rebuilds.single, wide);
    expect(coordinator.builtRange, wide);
  });

  test('an overlapping rebuild does not keep stale coverage', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = _CountingOccurrenceRepository(db);
    final coordinator = CalendarCacheCoordinator(repo);
    final first = _range(1, 20);
    final overlap = _range(10, 31);

    await coordinator.ensureRange(first);
    await coordinator.ensureRange(overlap);
    expect(repo.rebuilds, hasLength(2));
    expect(coordinator.builtRange, overlap);

    // The early slice of the first range was not re-materialized by the
    // overlapping rebuild, so it must be rebuilt instead of reported as
    // covered.
    await coordinator.ensureRange(_range(1, 10));
    expect(repo.rebuilds, hasLength(3));
    expect(coordinator.builtRange, _range(1, 10));
  });

  test('a disjoint range rebuilds', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = _CountingOccurrenceRepository(db);
    final coordinator = CalendarCacheCoordinator(repo);
    final later = _range(10, 15);

    await coordinator.ensureRange(_range(1, 5));
    await coordinator.ensureRange(later);

    expect(repo.rebuilds, hasLength(2));
    expect(coordinator.builtRange, later);
  });

  test('a failed rebuild does not poison the chain', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = _CountingOccurrenceRepository(db);
    final coordinator = CalendarCacheCoordinator(repo);
    final range = _range(1, 10);

    repo.failNext = StateError('boom');
    await expectLater(coordinator.ensureRange(range), throwsStateError);
    expect(coordinator.builtRange, isNull);

    await coordinator.ensureRange(range);
    expect(repo.rebuilds, hasLength(1));
    expect(repo.rebuilds.single, range);
    expect(coordinator.builtRange, range);
  });

  test('occurrences provider rebuilds the range and emits rows', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.calendars)
        .insert(
          CalendarsCompanion.insert(
            id: 'cal1',
            name: 'Calendar',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final start = DateTime.utc(2026, 3, 2, 9);
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'event1',
            calendarId: 'cal1',
            title: const Value('Standup'),
            startUtc: Value(start.millisecondsSinceEpoch),
            endUtc: Value(
              start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final repo = _CountingOccurrenceRepository(db)..materialize = true;
    final range = _range(1, 5);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        occurrenceRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      calendarRangeOccurrencesProvider(range),
      (_, _) {},
    );
    addTearDown(sub.close);
    final rows = await container.read(
      calendarRangeOccurrencesProvider(range).future,
    );

    expect(repo.rebuilds, hasLength(1));
    expect(rows, hasLength(1));
    expect(rows.single.eventId, 'event1');
    expect(rows.single.title, 'Standup');
    expect(container.read(calendarCacheCoordinatorProvider).builtRange, range);
  });
}
