// Bootstraps the occurrence cache for a Stream day when the Calendar screen
// is not mounted. Decides whether a rebuild is needed and tracks its
// lifecycle. See ARCHITECTURE.md.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/logger.dart' show AppLogger;
import '../../../data/repositories/occurrence_repository.dart'
    show OccurrenceRepository;
import '../../calendar/application/calendar_providers.dart'
    show
        calendarBuiltRangeProvider,
        calendarCacheBuildingProvider,
        occurrenceRepositoryProvider;
import '../../calendar/application/calendar_state.dart' show CalendarRange;

/// True when [requested] is not covered by [built] and no build is running.
///
/// A build in progress may still be materializing a different range, so the
/// caller must not start a competing rebuild.
bool needsStreamDayCacheRebuild({
  CalendarRange? built,
  required CalendarRange requested,
  required bool building,
}) {
  if (building) return false;
  return built == null || !built.covers(requested);
}

enum StreamDayCacheStatus { idle, loading, ready, error }

/// Narrow boundary so the controller can be tested without a database.
abstract interface class StreamDayCacheGateway {
  Future<void> rebuild(CalendarRange range);
}

class OccurrenceRepositoryStreamDayCacheGateway
    implements StreamDayCacheGateway {
  OccurrenceRepositoryStreamDayCacheGateway(this._repository);

  final OccurrenceRepository _repository;

  @override
  Future<void> rebuild(CalendarRange range) async {
    await _repository.rebuildWindow(
      windowStartUtc: range.fromUtc,
      windowEndUtc: range.toUtc,
    );
  }
}

final streamDayCacheGatewayProvider = Provider<StreamDayCacheGateway>((ref) {
  return OccurrenceRepositoryStreamDayCacheGateway(
    ref.watch(occurrenceRepositoryProvider),
  );
});

/// Owns at most one rebuild at a time and exposes its outcome to the UI.
class StreamDayCacheController extends Notifier<StreamDayCacheStatus> {
  final AppLogger _log = AppLogger();
  bool _inFlight = false;
  bool _disposed = false;
  CalendarRange? _active;
  CalendarRange? _pending;
  Object? _lastError;

  /// Error from the most recent failed rebuild, cleared on the next attempt.
  Object? get lastError => _lastError;

  @override
  StreamDayCacheStatus build() {
    ref.onDispose(() => _disposed = true);
    return StreamDayCacheStatus.idle;
  }

  /// Rebuilds the cache for [requested] unless it is already covered.
  ///
  /// Concurrent calls are coalesced: while a rebuild runs, a different range
  /// is remembered and handled once the current one finishes. Never throws.
  Future<void> ensure(CalendarRange requested) async {
    if (_disposed) return;
    if (_inFlight) {
      if (requested != _active) _pending = requested;
      return;
    }
    _active = requested;
    if (!needsStreamDayCacheRebuild(
      built: ref.read(calendarBuiltRangeProvider),
      requested: requested,
      building: ref.read(calendarCacheBuildingProvider),
    )) {
      _active = null;
      state = StreamDayCacheStatus.ready;
      return;
    }
    _inFlight = true;
    _lastError = null;
    state = StreamDayCacheStatus.loading;
    try {
      await ref.read(streamDayCacheGatewayProvider).rebuild(requested);
      if (_disposed) return;
      ref.read(calendarBuiltRangeProvider.notifier).markBuilt(requested);
      state = StreamDayCacheStatus.ready;
    } catch (error) {
      _lastError = error;
      _log.error('stream day cache rebuild failed', error);
      if (!_disposed) state = StreamDayCacheStatus.error;
    } finally {
      _inFlight = false;
      _active = null;
    }
    final pending = _pending;
    _pending = null;
    if (pending != null) await ensure(pending);
  }
}

final streamDayCacheControllerProvider =
    NotifierProvider<StreamDayCacheController, StreamDayCacheStatus>(
      StreamDayCacheController.new,
    );
