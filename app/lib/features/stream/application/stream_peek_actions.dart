// Saves Stream Peek task edits and rebuilds the affected occurrence day.
//
// Application layer only: no UI, no snackbars. Failures are typed so the
// surface owns user feedback.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/peek/peek_data.dart';
import 'stream_peek_gateway.dart';
import 'stream_peek_target.dart';

/// Outcome of a successful save.
sealed class StreamPeekResult {
  const StreamPeekResult();
}

/// The task was updated and the affected day was rebuilt.
final class StreamPeekSaved extends StreamPeekResult {
  const StreamPeekSaved();
}

/// The edit matched the snapshot, so nothing was written.
final class StreamPeekUnchanged extends StreamPeekResult {
  const StreamPeekUnchanged();
}

enum StreamPeekFailure {
  readOnly,
  missingTask,
  invalidEdit,
  listClearUnsupported,
  saveFailed,
}

/// Typed failure for the surface to translate into user feedback.
class StreamPeekException implements Exception {
  const StreamPeekException(this.reason, [this.message = '']);

  final StreamPeekFailure reason;
  final String message;

  @override
  String toString() => 'StreamPeekException(${reason.name}): $message';
}

class StreamPeekActions {
  const StreamPeekActions(this._gateway);

  final StreamPeekGateway _gateway;

  /// Saves a task edit.
  ///
  /// Validation mirrors the Peek editor: a non-blank title and an end that is
  /// not before the start. An edit identical to the snapshot returns
  /// [StreamPeekUnchanged] without writing. An unchanged priority writes the
  /// target's stored value, so Peek's collapse of P2/P1 into high cannot
  /// downgrade a task when only other fields change. Both the original and
  /// edited day are rebuilt (deduplicated, so a same-day edit rebuilds once)
  /// because a moved task leaves a stale row on its old day.
  Future<StreamPeekResult> save(StreamPeekTarget target, PeekEdit edit) async {
    if (!target.editable) {
      throw const StreamPeekException(StreamPeekFailure.readOnly);
    }
    final taskId = target.sourceTaskId;
    if (taskId == null) {
      throw const StreamPeekException(StreamPeekFailure.missingTask);
    }
    final validationError = _validate(edit);
    if (validationError != null) {
      throw StreamPeekException(StreamPeekFailure.invalidEdit, validationError);
    }
    // TaskRepository.updateTask treats a null list id as "leave unchanged",
    // so a clear cannot be applied. Reject it instead of reporting success.
    if (edit.listId == null && target.data.listId != null) {
      throw const StreamPeekException(StreamPeekFailure.listClearUnsupported);
    }
    if (_isUnchanged(target.data, edit)) return const StreamPeekUnchanged();
    try {
      await _gateway.updateTask(
        taskId: taskId,
        title: edit.title,
        plannedStart: _formatPlanned(edit.startMs),
        plannedEnd: edit.endMs == null ? null : _formatPlanned(edit.endMs!),
        listId: edit.listId,
        priority: _priorityForSave(target, edit),
        notes: edit.notes,
      );
      for (final day in _affectedDays(target.data.startMs, edit.startMs)) {
        await _gateway.rebuildDay(day);
      }
      return const StreamPeekSaved();
    } catch (_) {
      throw const StreamPeekException(StreamPeekFailure.saveFailed);
    }
  }
}

final streamPeekActionsProvider = Provider<StreamPeekActions>((ref) {
  return StreamPeekActions(ref.watch(streamPeekGatewayProvider));
});

// Keep the stored priority when the user leaves the level alone. Otherwise
// map Peek's four levels onto the task scale. Peek collapses P2 (3) and P1
// (4) into high, so choosing high writes the highest, 4 (P1).
int _priorityForSave(StreamPeekTarget target, PeekEdit edit) {
  if (edit.priority == target.data.priority) {
    return target.sourcePriority ?? _taskPriority(edit.priority);
  }
  return _taskPriority(edit.priority);
}

int _taskPriority(PeekPriority priority) => switch (priority) {
  PeekPriority.none => 0,
  PeekPriority.low => 1,
  PeekPriority.medium => 2,
  PeekPriority.high => 4,
};

String? _validate(PeekEdit edit) {
  if (edit.title.trim().isEmpty) return 'title is required';
  if (edit.endMs != null && edit.endMs! < edit.startMs) {
    return 'end must not be before start';
  }
  return null;
}

// The editor normalizes an empty notes field to null, so null and empty mean
// the same thing when deciding whether the user changed anything.
bool _isUnchanged(PeekData data, PeekEdit edit) =>
    data.title == edit.title &&
    data.startMs == edit.startMs &&
    data.endMs == edit.endMs &&
    data.listId == edit.listId &&
    data.priority == edit.priority &&
    (data.notes ?? '') == (edit.notes ?? '');

Set<int> _affectedDays(int originalStartMs, int editedStartMs) => {
  _dayStartMs(originalStartMs),
  _dayStartMs(editedStartMs),
};

int _dayStartMs(int ms) {
  final local = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateTime(local.year, local.month, local.day).millisecondsSinceEpoch;
}

// plannedStart/plannedEnd are stored as local wall-clock ISO strings without
// a zone, matching TaskRepository and the task editor.
String _formatPlanned(int ms) {
  final local = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${local.year.toString().padLeft(4, '0')}-'
      '${_two(local.month)}-${_two(local.day)}T'
      '${_two(local.hour)}:${_two(local.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
