import 'package:drift/native.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/countdown_repository.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/focus_repository.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/data/repositories/note_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/repositories/pending_operations_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/sync/application/pending_operations.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  test('skip occurrence advances due without completing', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final id = await repo.createTask(
      title: 'Gym',
      dueDate: '2026-03-02',
      rrule: 'FREQ=DAILY',
    );
    await repo.skipOccurrence(id);
    final tasks = await repo.evalSmartList({'showCompleted': false});
    expect(tasks.single.dueDate, '2026-03-03');
    expect(tasks.single.completedAt, isNull);
  });

  test('trash, restore and purge', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final id = await repo.createTask(title: 'Temp');
    await repo.softDeleteTasks([id]);
    expect(await repo.watchTrash().first, hasLength(1));
    expect(await repo.watchOpen().first, isEmpty);
    await repo.restoreTasks([id]);
    expect(await repo.watchOpen().first, hasLength(1));
    await repo.softDeleteTasks([id]);
    await repo.purgeTask(id);
    expect(await repo.watchTrash().first, isEmpty);
  });

  test('pending delete and purge hide optimistically', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final pending = PendingOperationsRepository(db);
    final id = await repo.createTask(title: 'Temp');

    final open = repo.watchOpen();
    final emptyUpdate = open
        .firstWhere((rows) => rows.isEmpty)
        .timeout(const Duration(seconds: 2));
    final deleteOp = await pending.enqueue(
      entity: 'task',
      entityId: id,
      op: 'delete',
    );
    expect(await emptyUpdate, isEmpty);
    final restored = open
        .firstWhere((rows) => rows.isNotEmpty)
        .timeout(const Duration(seconds: 2));
    await pending.cancel(deleteOp);
    expect(await restored, hasLength(1));

    await repo.softDeleteTasks([id]);
    final purgeOp = await pending.enqueue(
      entity: 'task',
      entityId: id,
      op: 'purge',
    );
    expect(await repo.watchTrash().first, isEmpty);
    await pending.cancel(purgeOp);
    expect(await repo.watchTrash().first, hasLength(1));
  });

  test('tags and smart list filter', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final a = await repo.createTask(title: 'A', priority: 4, tags: ['work']);
    await repo.createTask(title: 'B', priority: 1, tags: ['home']);
    final tagId = await repo.ensureTag('work');
    final byTag = await repo.evalSmartList({
      'tagIds': [tagId],
      'showCompleted': true,
    });
    expect(byTag.map((t) => t.id), [a]);
    final byPri = await repo.evalSmartList({
      'priorities': [4],
      'showCompleted': true,
    });
    expect(byPri.map((t) => t.id), [a]);
  });

  test('subtasks progress and move with undo mapping', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final l1 = await repo.createList('L1');
    final l2 = await repo.createList('L2');
    final parent = await repo.createTask(title: 'P', listId: l1);
    final sub = await repo.createTask(title: 'S', parentId: parent);
    expect(await repo.subtaskProgress(parent), [0, 1]);
    await repo.completeTask(sub);
    expect(await repo.subtaskProgress(parent), [1, 1]);
    final prev = await repo.moveTasks([parent], l2);
    expect(prev[parent], l1);
  });

  test(
    'moving a parent moves live children and preserves their fields',
    () async {
      final db = _db();
      addTearDown(db.close);
      final repo = TaskRepository(db);
      final l1 = await repo.createList('L1');
      final l2 = await repo.createList('L2');
      final unrelated = await repo.createTask(title: 'U', listId: l1);
      final parent = await repo.createTask(title: 'P', listId: l1);
      final child = await repo.createTask(
        title: 'S',
        parentId: parent,
        listId: l1,
        notes: 'child notes',
        priority: 3,
        dueDate: '2026-03-02',
        plannedStart: '2026-03-02T09:00',
      );
      final completed = await repo.createTask(
        title: 'Done',
        parentId: parent,
        listId: l1,
      );
      await repo.completeTask(completed);
      final deleted = await repo.createTask(
        title: 'Deleted',
        parentId: parent,
        listId: l1,
      );
      await repo.softDeleteTasks([deleted]);

      final prev = await repo.moveTasks([parent], l2);

      expect(prev.keys, containsAll([parent, child]));
      expect(prev[parent], l1);
      expect(prev[child], l1);
      expect(prev.keys, isNot(contains(unrelated)));
      expect(prev.keys, isNot(contains(completed)));
      expect(prev.keys, isNot(contains(deleted)));

      final rows = await db.select(db.tasks).get();
      final byId = {for (final row in rows) row.id: row};
      expect(byId[parent]!.listId, l2);
      expect(byId[child]!.listId, l2);
      expect(byId[unrelated]!.listId, l1);
      expect(byId[completed]!.listId, l1);
      expect(byId[deleted]!.listId, l1);
      expect(byId[child]!.notes, 'child notes');
      expect(byId[child]!.priority, 3);
      expect(byId[child]!.dueDate, '2026-03-02');
      expect(byId[child]!.plannedStart, '2026-03-02T09:00');
    },
  );

  test('moving a parent handles nested subtasks', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final l1 = await repo.createList('L1');
    final l2 = await repo.createList('L2');
    final parent = await repo.createTask(title: 'P', listId: l1);
    final child = await repo.createTask(
      title: 'S',
      parentId: parent,
      listId: l1,
    );
    final grandchild = await repo.createTask(
      title: 'G',
      parentId: child,
      listId: l1,
    );

    final prev = await repo.moveTasks([parent], l2);

    expect(prev.keys, containsAll([parent, child, grandchild]));
    final rows = await db.select(db.tasks).get();
    expect(rows.every((row) => row.listId == l2), isTrue);
  });

  test('move undo restores previous list', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final l1 = await repo.createList('A');
    final l2 = await repo.createList('B');
    final t = await repo.createTask(title: 'T', listId: l1);
    final prev = await repo.moveTasks([t], l2);
    expect(prev[t], l1);
    for (final e in prev.entries) {
      await repo.moveTasks([e.key], e.value);
    }
    final row = await (db.select(
      db.tasks,
    )..where((x) => x.id.equals(t))).getSingle();
    expect(row.listId, l1);
  });

  test('disposed pending operations ignore an in-flight schedule', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final first = await repo.createTask(title: 'First');
    final second = await repo.createTask(title: 'Second');
    final pendingRepo = PendingOperationsRepository(db);
    await pendingRepo.enqueue(
      entity: 'task',
      entityId: first,
      op: 'delete',
      delay: const Duration(milliseconds: 50),
    );
    final operations = PendingOperations(
      db,
      tasks: repo,
      notes: NoteRepository(db),
      habits: HabitRepository(db),
      countdowns: CountdownRepository(db),
      focus: FocusRepository(db),
      events: EventRepository(db, OccurrenceRepository(db)),
    );

    final scheduled = operations.scheduleTaskDelete(second);
    operations.dispose();
    await scheduled;
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final rows = await db.select(db.tasks).get();
    expect(rows.every((row) => row.deletedAt == null), isTrue);
    expect(await db.select(db.pendingOperations).get(), hasLength(2));
  });

  test('task reminders and alarm preset persist', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = TaskRepository(db);
    final id = await repo.createTask(
      title: 'Report',
      dueDate: '2026-03-02',
      reminders: '[5,0]',
      alarmPreset: 'full_short',
    );
    var row = await (db.select(
      db.tasks,
    )..where((x) => x.id.equals(id))).getSingle();
    expect(row.reminders, '[5,0]');
    expect(row.alarmPreset, 'full_short');
    await repo.updateTask(id, reminders: () => '[60]', alarmPreset: () => null);
    row = await (db.select(
      db.tasks,
    )..where((x) => x.id.equals(id))).getSingle();
    expect(row.reminders, '[60]');
    expect(row.alarmPreset, isNull);
  });
}
