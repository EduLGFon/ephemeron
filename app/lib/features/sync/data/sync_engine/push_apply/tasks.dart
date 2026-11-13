part of '../../sync_engine.dart';

extension on SyncEngine {
  Future<void> _applyTaskOp(GoogleApiClient client, OutboxData op) async {
    final t = await (_db.select(
      _db.tasks,
    )..where((x) => x.id.equals(op.entityId))).getSingleOrNull();
    if (t == null) return;
    final listId = await _remoteTaskListId(t.listId) ?? '@default';
    if (op.op == 'delete' || t.deletedAt != null) {
      if (t.remoteId != null) {
        await client.taskDelete(listId, t.remoteId!);
      }
      return;
    }
    if (op.op == 'move' && t.remoteId != null) {
      final p = _opPayload(op);
      final fromRemote =
          p['fromRemoteListId'] as String? ??
          (p['fromListId'] == null
              ? null
              : await _remoteTaskListId(p['fromListId'] as String));
      final destinationRemote = await _remoteTaskListId(t.listId);
      if (fromRemote != null &&
          destinationRemote != null &&
          fromRemote != destinationRemote) {
        final moved = await client.taskMove(
          fromRemote,
          t.remoteId!,
          destinationRemote,
        );
        await (_db.update(_db.tasks)..where((x) => x.id.equals(t.id))).write(
          TasksCompanion(
            remoteId: Value(moved['id'] as String? ?? t.remoteId),
            remoteEtag: Value(moved['etag'] as String?),
            dirty: const Value(false),
          ),
        );
        return;
      }
    }
    if (t.remoteId == null) {
      final created = await client.taskInsert(listId, taskToGoogle(t));
      await (_db.update(_db.tasks)..where((x) => x.id.equals(t.id))).write(
        TasksCompanion(
          remoteId: Value(created['id'] as String?),
          remoteEtag: Value(created['etag'] as String?),
          dirty: const Value(false),
        ),
      );
    } else {
      final updated = await client.taskPatch(
        listId,
        t.remoteId!,
        taskToGoogle(t),
        etag: t.remoteEtag,
      );
      await (_db.update(_db.tasks)..where((x) => x.id.equals(t.id))).write(
        TasksCompanion(
          remoteEtag: Value(updated['etag'] as String?),
          dirty: const Value(false),
        ),
      );
    }
  }

  Future<void> _applyTaskListOp(GoogleApiClient client, OutboxData op) async {
    final list = await (_db.select(
      _db.taskLists,
    )..where((l) => l.id.equals(op.entityId))).getSingleOrNull();
    if (list == null) return;
    if (op.op == 'delete' || list.deletedAt != null) {
      if (list.remoteId != null) {
        await client.taskListDelete(list.remoteId!);
      }
      await _hardDeleteTaskList(list.id);
      return;
    }
    if (list.remoteId == null) {
      final created = await client.taskListCreate(list.name);
      await (_db.update(
        _db.taskLists,
      )..where((l) => l.id.equals(list.id))).write(
        TaskListsCompanion(
          remoteId: Value(created['id'] as String?),
          remoteEtag: Value(created['etag'] as String?),
          dirty: const Value(false),
        ),
      );
    } else {
      final updated = await client.taskListPatch(list.remoteId!, list.name);
      await (_db.update(
        _db.taskLists,
      )..where((l) => l.id.equals(list.id))).write(
        TaskListsCompanion(
          remoteEtag: Value(updated['etag'] as String?),
          dirty: const Value(false),
        ),
      );
    }
  }
}
