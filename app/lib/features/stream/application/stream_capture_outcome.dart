// Typed capture execution results. No UI or repository imports.
import '../capture/capture_kind.dart';

enum StreamCaptureFailure {
  emptyTitle,
  endBeforeStart,
  missingDate,
  listFailed,
  calendarFailed,
  createFailed,
  refreshFailed,
}

class StreamCaptureException implements Exception {
  const StreamCaptureException(this.reason, {this.cause});

  final StreamCaptureFailure reason;
  final Object? cause;

  @override
  String toString() => 'StreamCaptureException(${reason.name})';
}

class CaptureOutcome {
  const CaptureOutcome({
    required this.kind,
    required this.id,
    this.scheduledDay,
  });

  final CaptureKind kind;
  final String id;

  /// Local day the entity was scheduled on; null for unscheduled tasks.
  final DateTime? scheduledDay;
}
