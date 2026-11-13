// Non-personal sync diagnostics carried to the "Sync issues" screen.
//
// PRIVACY: these models deliberately contain no payload, token, account email,
// event title, task title, or raw server response. Error labels are produced
// by a closed allowlist so a malformed or imported value cannot leak content.
enum SyncStateIssueKind { calendar, taskList }

class SyncOutboxIssue {
  const SyncOutboxIssue({
    required this.id,
    required this.operationLabel,
    required this.entityLabel,
    required this.attempts,
    required this.createdAtUtc,
    required this.errorLabel,
    required this.failed,
  });

  final String id;
  final String operationLabel;
  final String entityLabel;
  final int attempts;
  final DateTime createdAtUtc;
  final String errorLabel;

  /// Attempts are exhausted. Only these rows may be discarded.
  final bool failed;
}

class SyncStateIssue {
  const SyncStateIssue({
    required this.key,
    required this.kind,
    required this.errorLabel,
    required this.lastSyncAtUtc,
  });

  final String key;
  final SyncStateIssueKind kind;
  final String errorLabel;
  final DateTime? lastSyncAtUtc;
}

String syncEntityLabel(String entity) {
  if (entity == 'event' || entity == 'event_remote') return 'Event';
  if (entity == 'task' || entity == 'task_remote') return 'Task';
  if (entity == 'task_list') return 'Task list';
  if (entity == 'habit' || entity.startsWith('habit_log')) return 'Habit';
  if (entity == 'focus') return 'Focus session';
  return 'Change';
}

String syncOperationLabel(String op) {
  switch (op) {
    case 'create':
      return 'Create';
    case 'update':
    case 'patch':
      return 'Update';
    case 'delete':
    case 'delete_occurrence':
      return 'Delete';
    case 'move':
      return 'Move';
    default:
      return 'Change';
  }
}

/// Maps a persisted error string to a fixed, non-personal label. Never echoes
/// the stored value.
String syncErrorLabel(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  if (value.isEmpty) return 'Sync failed';
  if (value.contains('auth') ||
      value.contains('permission') ||
      value.contains('401')) {
    return 'Needs permission';
  }
  if (value.contains('rate') || value.contains('429')) return 'Rate limited';
  if (value.contains('forbidden') || value.contains('403')) {
    return 'Access denied';
  }
  if (value.contains('404') ||
      value.contains('not found') ||
      value.contains('gone')) {
    return 'No longer available';
  }
  if (value.contains('network') ||
      value.contains('socket') ||
      value.contains('timeout') ||
      value.contains('offline')) {
    return 'No connection';
  }
  if (value.contains('server') ||
      value.contains('500') ||
      value.contains('502') ||
      value.contains('503') ||
      value.contains('504')) {
    return 'Server error';
  }
  if (value.startsWith('failed:') || value.startsWith('error ')) {
    return 'Change was rejected';
  }
  return 'Sync failed';
}

String syncIssueAgeLabel(DateTime? atUtc, {DateTime? nowUtc}) {
  if (atUtc == null) return 'unknown age';
  final now = (nowUtc ?? DateTime.now()).toUtc();
  final delta = now.difference(atUtc.toUtc());
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inHours < 1) return '${delta.inMinutes}m ago';
  if (delta.inDays < 1) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}
