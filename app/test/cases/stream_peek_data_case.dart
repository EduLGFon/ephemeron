import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/application/stream_peek_data.dart';
import 'package:ephemeron/features/stream/presentation/peek/peek_data.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fixtures.dart';

late AppDatabase db;

class _FakeGateway implements StreamPeekGateway {
  int updateCalls = 0;
  int rebuildCalls = 0;
  String? taskId;
  String? title;
  String? plannedStart;
  String? plannedEnd;
  String? listId;
  int? priority;
  String? notes;
  final List<int> rebuiltDays = <int>[];
  Object? updateError;
  Object? rebuildError;

  @override
  Future<void> updateTask({
    required String taskId,
    required String title,
    required String plannedStart,
    required String? plannedEnd,
    required String? listId,
    required int priority,
    required String? notes,
  }) async {
    updateCalls++;
    this.taskId = taskId;
    this.title = title;
    this.plannedStart = plannedStart;
    this.plannedEnd = plannedEnd;
    this.listId = listId;
    this.priority = priority;
    this.notes = notes;
    if (updateError != null) throw updateError!;
  }

  @override
  Future<void> rebuildDay(int dayStartMs) async {
    rebuildCalls++;
    rebuiltDays.add(dayStartMs);
    if (rebuildError != null) throw rebuildError!;
  }
}

Task _task({
  String id = 't1',
  String title = 'Task',
  String? listId = 'l1',
  String? notes,
  int priority = 0,
  String? plannedStart,
  String? plannedEnd,
}) {
  return Task(
    id: id,
    title: title,
    listId: listId,
    notes: notes,
    priority: priority,
    plannedStart: plannedStart,
    plannedEnd: plannedEnd,
    pinned: false,
    wontDo: false,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    dirty: false,
  );
}

TaskList _list({String id = 'l1', String name = 'Work'}) {
  return TaskList(
    id: id,
    name: name,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    dirty: false,
  );
}

int _at(int hour, [int minute = 0]) =>
    DateTime(2026, 11, 17, hour, minute).millisecondsSinceEpoch;

StreamDayMark _taskMark({
  String id = 'occurrence-1',
  String? sourceId = 't1',
  String title = 'Task',
  int? startMs,
  int? endMs,
}) {
  return StreamDayMark(
    id: id,
    kind: StreamDayMarkKind.task,
    startMs: startMs ?? _at(9),
    endMs: endMs ?? _at(10),
    title: title,
    colorArgb: 0xFF123456,
    sourceTaskOrEventId: sourceId,
  );
}

StreamDayMark _eventMark({String? sourceId = 'event-1'}) {
  return StreamDayMark(
    id: 'occurrence-event',
    kind: StreamDayMarkKind.event,
    startMs: _at(11),
    endMs: _at(12),
    title: 'Meeting',
    colorArgb: 0xFF654321,
    sourceTaskOrEventId: sourceId,
  );
}

ProviderContainer _container({
  List<Task> tasks = const <Task>[],
  List<TaskList> lists = const <TaskList>[],
  StreamPeekGateway? gateway,
}) {
  final container = ProviderContainer(
    overrides: [
      openTasksProvider.overrideWith((ref, listId) => Stream.value(tasks)),
      taskListsProvider.overrideWith((ref) => Stream.value(lists)),
      streamPeekGatewayProvider.overrideWithValue(gateway ?? _FakeGateway()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

PeekData _priorityData(PeekPriority priority) {
  return PeekData(
    id: 't1',
    title: 'Old',
    startMs: _at(9),
    endMs: _at(10),
    listId: 'l1',
    listName: 'Work',
    priority: priority,
    notes: 'old note',
  );
}

StreamPeekTarget _target({
  bool editable = true,
  String? sourceTaskId = 't1',
  PeekData? data,
  int? sourcePriority = 1,
}) {
  return StreamPeekTarget(
    data: data ?? _priorityData(PeekPriority.low),
    editable: editable,
    sourceTaskId: sourceTaskId,
    sourcePriority: sourcePriority,
  );
}

PeekEdit _edit({
  String title = 'Edited',
  int? startMs,
  int? endMs,
  String? listId = 'l2',
  PeekPriority priority = PeekPriority.high,
  String? notes = 'new note',
}) {
  return PeekEdit(
    title: title,
    startMs: startMs ?? _at(14, 15),
    endMs: endMs ?? _at(15, 15),
    listId: listId,
    priority: priority,
    notes: notes,
  );
}

/// Edit that changes only the requested fields from [target].
PeekEdit _editFor(
  StreamPeekTarget target, {
  String? title,
  PeekPriority? priority,
}) {
  return PeekEdit(
    title: title ?? target.data.title,
    startMs: target.data.startMs,
    endMs: target.data.endMs,
    listId: target.data.listId,
    priority: priority ?? target.data.priority,
    notes: target.data.notes,
  );
}

Matcher _failsWith(StreamPeekFailure reason) => throwsA(
  isA<StreamPeekException>().having((e) => e.reason, 'reason', reason),
);

// Reading .future alone does not subscribe in Riverpod 3, so keep a listener
// alive for the duration of the read.
Future<StreamPeekTarget?> _readTarget(
  ProviderContainer container,
  StreamDayMark mark,
) async {
  final provider = streamPeekTargetProvider(mark);
  final subscription = container.listen(provider, (_, _) {});
  addTearDown(subscription.close);
  return container.read(provider.future);
}

void main() {
  setUpAll(() {
    db = newTestDb();
  });
  setUp(() => resetTestDb(db));
  tearDownAll(() async {
    await db.close();
  });
  test('task mark maps task title, time, list, priority and notes', () async {
    final container = _container(
      tasks: [
        _task(
          title: 'Plan',
          listId: 'l1',
          notes: 'note',
          priority: 2,
          plannedStart: '2026-11-17T09:00',
          plannedEnd: '2026-11-17T10:00',
        ),
      ],
      lists: [_list(id: 'l1', name: 'Work')],
    );

    final target = await _readTarget(container, _taskMark());

    expect(target, isNotNull);
    expect(target!.editable, isTrue);
    expect(target.sourceTaskId, 't1');
    expect(target.data.id, 't1');
    expect(target.data.title, 'Plan');
    expect(target.data.startMs, _at(9));
    expect(target.data.endMs, _at(10));
    expect(target.data.listId, 'l1');
    expect(target.data.listName, 'Work');
    expect(target.data.priority, PeekPriority.medium);
    expect(target.sourcePriority, 2);
    expect(target.data.notes, 'note');
  });

  test('missing task mark returns null', () async {
    final container = _container(tasks: [_task(id: 'other')]);
    final target = await _readTarget(container, _taskMark(sourceId: 'gone'));
    expect(target, isNull);
  });

  test('event mark maps read-only without list or task id', () async {
    final container = _container();
    final target = await _readTarget(container, _eventMark());

    expect(target, isNotNull);
    expect(target!.editable, isFalse);
    expect(target.sourceTaskId, isNull);
    expect(target.data.id, 'occurrence-event');
    expect(target.data.title, 'Meeting');
    expect(target.data.startMs, _at(11));
    expect(target.data.endMs, _at(12));
    expect(target.data.listId, isNull);
    expect(target.data.listName, isNull);
    expect(target.data.priority, PeekPriority.none);
    expect(target.data.notes, isNull);
  });

  test('save writes the exact task edit and rebuilds the day once', () async {
    final gateway = _FakeGateway();
    final actions = StreamPeekActions(gateway);

    final result = await actions.save(_target(), _edit());

    expect(result, isA<StreamPeekSaved>());
    expect(gateway.updateCalls, 1);
    expect(gateway.taskId, 't1');
    expect(gateway.title, 'Edited');
    expect(gateway.plannedStart, '2026-11-17T14:15');
    expect(gateway.plannedEnd, '2026-11-17T15:15');
    expect(gateway.listId, 'l2');
    expect(gateway.priority, 4);
    expect(gateway.notes, 'new note');
    expect(gateway.rebuildCalls, 1);
    expect(gateway.rebuiltDays, [
      DateTime(2026, 11, 17).millisecondsSinceEpoch,
    ]);
  });

  test('a title-only edit keeps stored P1 (4)', () async {
    final gateway = _FakeGateway();
    final target = _target(
      data: _priorityData(PeekPriority.high),
      sourcePriority: 4,
    );

    await StreamPeekActions(gateway)
        .save(target, _editFor(target, title: 'Renamed'));

    expect(gateway.priority, 4);
  });

  test('a title-only edit keeps stored P2 (3)', () async {
    final gateway = _FakeGateway();
    final target = _target(
      data: _priorityData(PeekPriority.high),
      sourcePriority: 3,
    );

    await StreamPeekActions(gateway)
        .save(target, _editFor(target, title: 'Renamed'));

    expect(gateway.priority, 3);
  });

  test('choosing high writes P1 (4)', () async {
    final gateway = _FakeGateway();
    final target = _target(
      data: _priorityData(PeekPriority.low),
      sourcePriority: 1,
    );

    await StreamPeekActions(gateway)
        .save(target, _editFor(target, priority: PeekPriority.high));

    expect(gateway.priority, 4);
  });

  test('choosing medium writes 2', () async {
    final gateway = _FakeGateway();
    final target = _target(
      data: _priorityData(PeekPriority.high),
      sourcePriority: 4,
    );

    await StreamPeekActions(gateway)
        .save(target, _editFor(target, priority: PeekPriority.medium));

    expect(gateway.priority, 2);
  });

  test('the actions provider uses the injected gateway', () async {
    final gateway = _FakeGateway();
    final container = _container(gateway: gateway);

    final result = await container
        .read(streamPeekActionsProvider)
        .save(_target(), _edit());

    expect(result, isA<StreamPeekSaved>());
    expect(gateway.updateCalls, 1);
  });

  test('a moved task rebuilds both the old and the new day', () async {
    final gateway = _FakeGateway();
    final actions = StreamPeekActions(gateway);

    await actions.save(
      _target(),
      _edit(
        startMs: DateTime(2026, 11, 18, 14).millisecondsSinceEpoch,
        endMs: DateTime(2026, 11, 18, 15).millisecondsSinceEpoch,
      ),
    );

    expect(gateway.rebuildCalls, 2);
    expect(gateway.rebuiltDays, [
      DateTime(2026, 11, 17).millisecondsSinceEpoch,
      DateTime(2026, 11, 18).millisecondsSinceEpoch,
    ]);
  });

  test('rebuildDay keeps the adjacent cache days D-2 and D+3', () async {
    final tasks = TaskRepository(db);
    for (var day = 15; day <= 20; day++) {
      final key = '2026-11-${day.toString().padLeft(2, '0')}';
      await tasks.createTask(
        title: 'Task $day',
        plannedStart: '${key}T09:00',
        plannedEnd: '${key}T10:00',
      );
    }
    final occurrences = OccurrenceRepository(db);
    await occurrences.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 11, 13),
      windowEndUtc: DateTime.utc(2026, 11, 21),
    );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container
        .read(streamPeekGatewayProvider)
        .rebuildDay(DateTime(2026, 11, 17).millisecondsSinceEpoch);

    final rows = await (db.select(db.occurrenceCache)).get();
    final days = {for (final row in rows) row.dayKey};
    expect(days, contains('2026-11-15'));
    expect(days, contains('2026-11-20'));
  });

  test('clearing a list fails instead of silently succeeding', () async {
    final gateway = _FakeGateway();
    final target = _target();
    final edit = PeekEdit(
      title: target.data.title,
      startMs: target.data.startMs,
      endMs: target.data.endMs,
      listId: null,
      priority: target.data.priority,
      notes: target.data.notes,
    );

    await expectLater(
      StreamPeekActions(gateway).save(target, edit),
      _failsWith(StreamPeekFailure.listClearUnsupported),
    );
    expect(gateway.updateCalls, 0);
  });

  test('a no-op save writes nothing', () async {
    final gateway = _FakeGateway();
    final target = _target(
      data: _priorityData(PeekPriority.high),
      sourcePriority: 4,
    );

    final result = await StreamPeekActions(gateway)
        .save(target, _editFor(target));

    expect(result, isA<StreamPeekUnchanged>());
    expect(gateway.updateCalls, 0);
    expect(gateway.rebuildCalls, 0);
  });

  test('event and missing-task targets fail with typed reasons', () async {
    final actions = StreamPeekActions(_FakeGateway());

    await expectLater(
      actions.save(_target(editable: false, sourceTaskId: null), _edit()),
      _failsWith(StreamPeekFailure.readOnly),
    );
    await expectLater(
      actions.save(_target(sourceTaskId: null), _edit()),
      _failsWith(StreamPeekFailure.missingTask),
    );
  });

  test('invalid edits fail before any write', () async {
    final gateway = _FakeGateway();
    final actions = StreamPeekActions(gateway);

    await expectLater(
      actions.save(_target(), _edit(title: '   ')),
      _failsWith(StreamPeekFailure.invalidEdit),
    );
    await expectLater(
      actions.save(_target(), _edit(startMs: _at(15), endMs: _at(14))),
      _failsWith(StreamPeekFailure.invalidEdit),
    );
    expect(gateway.updateCalls, 0);
    expect(gateway.rebuildCalls, 0);
  });

  test('repository failures become a typed save failure', () async {
    final updateFailure = _FakeGateway()..updateError = StateError('update');
    await expectLater(
      StreamPeekActions(updateFailure).save(_target(), _edit()),
      _failsWith(StreamPeekFailure.saveFailed),
    );

    final rebuildFailure = _FakeGateway()..rebuildError = StateError('rebuild');
    await expectLater(
      StreamPeekActions(rebuildFailure).save(_target(), _edit()),
      _failsWith(StreamPeekFailure.saveFailed),
    );
  });
}
