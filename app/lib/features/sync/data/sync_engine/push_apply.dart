part of '../sync_engine.dart';

extension on SyncEngine {
  Future<void> _applyOp(GoogleApiClient client, OutboxData op) async {
    if (op.entity == 'event_remote') {
      final p = _opPayload(op);
      final calendarRemoteId = p['calendarRemoteId'] as String?;
      final eventRemoteId = p['eventRemoteId'] as String?;
      if (calendarRemoteId != null && eventRemoteId != null) {
        await client.eventDelete(calendarRemoteId, eventRemoteId);
      }
      return;
    }
    if (op.entity == 'task_remote') {
      final p = _opPayload(op);
      final listRemoteId = p['listRemoteId'] as String?;
      final taskRemoteId = p['taskRemoteId'] as String?;
      if (listRemoteId != null && taskRemoteId != null) {
        await client.taskDelete(listRemoteId, taskRemoteId);
      }
      return;
    }
    if (op.entity == 'event') {
      await _applyEventOp(client, op);
    } else if (op.entity == 'task') {
      await _applyTaskOp(client, op);
    } else if (op.entity == 'task_list') {
      await _applyTaskListOp(client, op);
    }
  }
}
