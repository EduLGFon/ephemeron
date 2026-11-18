// Single-flight coordinator for the calendar occurrence cache.
//
// Today and Calendar both materialize `occurrence_cache` rows, so rebuilds
// must be serialized: a rebuild deletes and re-inserts a whole slice, and two
// overlapping rebuilds racing would expose a partial window.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/repositories/occurrence_repository.dart';
import 'calendar_providers.dart';
import 'calendar_state.dart';

/// Serializes [OccurrenceRepository.rebuildWindow] calls for the calendar UI.
///
/// Coverage is the latest range that was fully rebuilt. A rebuild deletes rows
/// overlapping its range (plus a one-day day-key padding), so ranges built
/// earlier cannot be merged back into the claimed coverage: parts of them may
/// already be obsolete. Keeping one range is conservative and never reports
/// deleted rows as materialized.
class CalendarCacheCoordinator {
  CalendarCacheCoordinator(this._repository);

  final OccurrenceRepository _repository;

  CalendarRange? _builtRange;
  Future<void> _chain = Future<void>.value();

  /// Latest range whose occurrence rows are fully materialized.
  CalendarRange? get builtRange => _builtRange;

  /// Materializes [range] unless [builtRange] already covers it.
  ///
  /// Concurrent requests share one future chain and re-check coverage after
  /// the previous rebuild completes, so requests coalesced behind a wider
  /// rebuild do not rebuild the same rows again.
  Future<void> ensureRange(CalendarRange range) {
    final built = _builtRange;
    if (built != null && built.covers(range)) return Future<void>.value();

    final rebuild = _chain.then((_) async {
      final current = _builtRange;
      if (current != null && current.covers(range)) return;
      await _repository.rebuildWindow(
        windowStartUtc: range.fromUtc,
        windowEndUtc: range.toUtc,
      );
      _builtRange = range;
    });
    // A failed rebuild must not block or poison later requests. Callers still
    // observe the failure through the returned future.
    _chain = rebuild.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return rebuild;
  }
}

final calendarCacheCoordinatorProvider = Provider<CalendarCacheCoordinator>((
  ref,
) {
  return CalendarCacheCoordinator(ref.watch(occurrenceRepositoryProvider));
});

/// Occurrence rows for [range], rebuilt first only when not already covered.
///
/// The stream waits for [CalendarCacheCoordinator.ensureRange] so consumers
/// never render the pre-rebuild snapshot, then follows the Drift table.
final calendarRangeOccurrencesProvider =
    StreamProvider.family<List<OccurrenceCacheData>, CalendarRange>((
      ref,
      range,
    ) {
      final repository = ref.watch(occurrenceRepositoryProvider);
      final coordinator = ref.watch(calendarCacheCoordinatorProvider);
      return _watchAfterRebuild(coordinator, repository, range);
    });

Stream<List<OccurrenceCacheData>> _watchAfterRebuild(
  CalendarCacheCoordinator coordinator,
  OccurrenceRepository repository,
  CalendarRange range,
) async* {
  await coordinator.ensureRange(range);
  yield* repository.watchWindow(range.fromUtc, range.toUtc);
}

/// Habit entries for [range]. Habits are not materialized in the occurrence
/// cache, so this reuses [calendarHabitEntriesProvider] directly.
final calendarRangeHabitEntriesProvider = calendarHabitEntriesProvider;
