import 'package:ephemeron/data/drift/app_database.dart' show Task, TaskList;
import 'package:ephemeron/features/stream/application/stream_slipped_data.dart';
import 'package:ephemeron/features/stream/presentation/slipped/slipped_item.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart'
    show openTasksProvider, taskListsByIdProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('streamSlippedItemsProvider', () {
    test('filters dates before today, excludes today/future/invalid', () async {
      final today = DateTime(2026, 3, 30);
      final lists = {'l': _list('l', color: '#112233')};
      final container = _itemsContainer(
        today: today,
        lists: lists,
        tasks: [
          _task(id: 'due', title: 'Due', dueDate: '2026-03-27', listId: 'l'),
          _task(
            id: 'planned',
            title: 'Planned',
            plannedDate: '2026-03-29',
            listId: 'l',
          ),
          _task(id: 'today', title: 'Today', dueDate: '2026-03-30'),
          _task(id: 'future', title: 'Future', plannedDate: '2026-04-02'),
          _task(id: 'none', title: 'None'),
          _task(id: 'invalid', title: 'Invalid', dueDate: '2026-02-30'),
          _task(
            id: 'completed',
            title: 'Completed',
            dueDate: '2026-03-20',
            completedAt: 1,
          ),
          _task(
            id: 'deleted',
            title: 'Deleted',
            dueDate: '2026-03-20',
            deletedAt: 1,
          ),
          _task(
            id: 'both',
            title: 'Both',
            dueDate: '2026-03-27',
            plannedDate: '2026-03-29',
            listId: 'l',
          ),
        ],
      );
      addTearDown(container.dispose);

      final items = await _items(container);

      expect(items.map((item) => item.id), ['both', 'due', 'planned']);
      expect(items.first.daysOverdue, 3);
      expect(items.first.listColorArgb, 0xFF112233);
      expect(items.last.daysOverdue, 1);
    });

    test('daysOverdue is UTC-normalized across DST boundaries', () async {
      final spring = await _items(
        _itemsContainer(
          today: DateTime(2026, 3, 30),
          tasks: [_task(id: 'spring', dueDate: '2026-03-27')],
        ),
      );
      final autumn = await _items(
        _itemsContainer(
          today: DateTime(2026, 10, 26),
          tasks: [_task(id: 'autumn', dueDate: '2026-10-23')],
        ),
      );

      expect(spring.single.daysOverdue, 3);
      expect(autumn.single.daysOverdue, 3);
    });

    test('orders by days overdue, then title, then id', () async {
      final container = _itemsContainer(
        today: DateTime(2026, 3, 30),
        tasks: [
          _task(id: 'b', title: 'Same', dueDate: '2026-03-28'),
          _task(id: 'a', title: 'Same', dueDate: '2026-03-28'),
          _task(id: 'c', title: 'Aardvark', dueDate: '2026-03-28'),
          _task(id: 'd', title: 'Zed', dueDate: '2026-03-29'),
          _task(id: 'e', title: 'Alpha', dueDate: '2026-03-27'),
        ],
      );
      addTearDown(container.dispose);

      final items = await _items(container);

      expect(items.map((item) => item.id), ['e', 'c', 'a', 'b', 'd']);
    });

    test('deduplicates ids and keeps the most overdue row', () async {
      final container = _itemsContainer(
        today: DateTime(2026, 3, 30),
        tasks: [
          _task(id: 'dup', title: 'Older', dueDate: '2026-03-26'),
          _task(id: 'dup', title: 'Newer', dueDate: '2026-03-29'),
        ],
      );
      addTearDown(container.dispose);

      final items = await _items(container);

      expect(items, hasLength(1));
      expect(items.single.id, 'dup');
      expect(items.single.daysOverdue, 4);
    });

    test('empty source yields an empty list', () async {
      final container = _itemsContainer(
        today: DateTime(2026, 3, 30),
        tasks: const [],
      );
      addTearDown(container.dispose);

      expect(await _items(container), isEmpty);
    });

    test('handles 500 tasks in deterministic order', () async {
      final tasks = List.generate(
        500,
        (i) => _task(
          id: 't${i.toString().padLeft(3, '0')}',
          title: 'Task ${i.toString().padLeft(3, '0')}',
          dueDate: '2026-03-29',
        ),
      );
      final container = _itemsContainer(
        today: DateTime(2026, 3, 30),
        tasks: tasks,
      );
      addTearDown(container.dispose);

      final items = await _items(container);

      expect(items, hasLength(500));
      expect(items.first.id, 't000');
      expect(items.last.id, 't499');
    });
  });

  group('StreamSlippedActions', () {
    test('done completes and undo uncompletes, rebuilding old days', () async {
      final gateway = _FakeGateway(
        task: _snapshot(
          dueDate: '2026-03-27',
          plannedDate: '2026-03-28',
          plannedStart: '2026-03-28T09:00',
        ),
      );
      final container = _actionsContainer(gateway);
      addTearDown(container.dispose);

      final result = await container
          .read(streamSlippedActionsProvider)
          .done('t');

      expect(gateway.completeCalls, ['t']);
      expect(gateway.rebuildDays.map(_dayKey), ['2026-3-27', '2026-3-28']);
      expect(result.taskId, 't');
      expect(result.undo, isNotNull);

      await result.undo!();
      expect(gateway.uncompleteCalls, ['t']);
      expect(gateway.rebuildDays, hasLength(4));
    });

    test('tomorrow shifts due/planned fields and keeps planned time', () async {
      final gateway = _FakeGateway(
        task: _snapshot(
          dueDate: '2026-03-27',
          plannedDate: '2026-03-28',
          plannedStart: '2026-03-28T09:15',
          plannedEnd: '2026-03-28T09:45',
        ),
      );
      final container = _actionsContainer(gateway);
      addTearDown(container.dispose);

      final result = await container
          .read(streamSlippedActionsProvider)
          .tomorrow('t');

      final update = gateway.updateCalls.single;
      expect(update.id, 't');
      expect(update.dueDate, '2026-03-31');
      expect(update.plannedDate, '2026-03-31');
      expect(update.plannedStart, '2026-03-31T09:15');
      expect(update.plannedEnd, '2026-03-31T09:45');
      expect(gateway.rebuildDays.map(_dayKey), [
        '2026-3-27',
        '2026-3-28',
        '2026-3-31',
      ]);

      await result.undo!();
      final undo = gateway.updateCalls.last;
      expect(undo.dueDate, '2026-03-27');
      expect(undo.plannedDate, '2026-03-28');
      expect(undo.plannedStart, '2026-03-28T09:15');
      expect(undo.plannedEnd, '2026-03-28T09:45');
      expect(gateway.rebuildDays, hasLength(6));
    });

    test('tomorrow preserves wall time across a DST change', () async {
      final gateway = _FakeGateway(
        task: _snapshot(plannedStart: '2026-03-28T09:00'),
      );
      final container = _actionsContainer(
        gateway,
        today: DateTime(2026, 3, 28, 12),
      );
      addTearDown(container.dispose);

      await container.read(streamSlippedActionsProvider).tomorrow('t');

      expect(gateway.updateCalls.single.plannedStart, '2026-03-29T09:00');
    });

    test('pickTime sets planned interval and planned date', () async {
      final gateway = _FakeGateway(
        task: _snapshot(
          dueDate: '2026-03-22',
          plannedDate: '2026-03-20',
          plannedStart: '2026-03-20T08:00',
          plannedEnd: '2026-03-20T08:30',
        ),
      );
      final container = _actionsContainer(gateway);
      addTearDown(container.dispose);

      final result = await container
          .read(streamSlippedActionsProvider)
          .pickTime(
            't',
            DateTime(2026, 3, 31, 14, 45),
            duration: const Duration(minutes: 45),
          );

      final update = gateway.updateCalls.single;
      expect(update.dueDate, '2026-03-22');
      expect(update.plannedDate, '2026-03-31');
      expect(update.plannedStart, '2026-03-31T14:45');
      expect(update.plannedEnd, '2026-03-31T15:30');
      expect(gateway.rebuildDays.map(_dayKey), [
        '2026-3-20',
        '2026-3-22',
        '2026-3-31',
      ]);

      await result.undo!();
      final undo = gateway.updateCalls.last;
      expect(undo.plannedDate, '2026-03-20');
      expect(undo.plannedStart, '2026-03-20T08:00');
      expect(undo.plannedEnd, '2026-03-20T08:30');
    });

    test('pickTime defaults to 30 minutes', () async {
      final gateway = _FakeGateway(task: _snapshot(plannedDate: '2026-03-20'));
      final container = _actionsContainer(gateway);
      addTearDown(container.dispose);

      await container
          .read(streamSlippedActionsProvider)
          .pickTime('t', DateTime(2026, 3, 31, 14, 45));

      expect(gateway.updateCalls.single.plannedEnd, '2026-03-31T15:15');
    });

    test('drop soft-deletes and undo restores', () async {
      final gateway = _FakeGateway(task: _snapshot(dueDate: '2026-03-27'));
      final container = _actionsContainer(gateway);
      addTearDown(container.dispose);

      final result = await container
          .read(streamSlippedActionsProvider)
          .drop('t');

      expect(gateway.deleteCalls, ['t']);
      expect(gateway.rebuildDays.map(_dayKey), ['2026-3-27']);

      await result.undo!();
      expect(gateway.restoreCalls, ['t']);
      expect(gateway.rebuildDays, hasLength(2));
    });

    test('missing task maps to a typed exception', () async {
      final container = _actionsContainer(_FakeGateway());
      addTearDown(container.dispose);

      await expectLater(
        container.read(streamSlippedActionsProvider).done('missing'),
        throwsA(
          isA<StreamSlippedException>().having(
            (error) => error.failure,
            'failure',
            StreamSlippedFailure.missingTask,
          ),
        ),
      );
    });

    test('repository failure maps to a typed exception', () async {
      final gateway = _FakeGateway(task: _snapshot(dueDate: '2026-03-27'))
        ..completeError = StateError('db failed');
      final container = _actionsContainer(gateway);
      addTearDown(container.dispose);

      await expectLater(
        container.read(streamSlippedActionsProvider).done('t'),
        throwsA(
          isA<StreamSlippedException>().having(
            (error) => error.failure,
            'failure',
            StreamSlippedFailure.repository,
          ),
        ),
      );
    });
  });
}

ProviderContainer _itemsContainer({
  required DateTime today,
  required List<Task> tasks,
  Map<String, TaskList> lists = const {},
}) {
  return ProviderContainer(
    overrides: [
      openTasksProvider(null).overrideWith((ref) => Stream.value(tasks)),
      taskListsByIdProvider.overrideWithValue(lists),
      streamSlippedClockProvider.overrideWithValue(() => today),
    ],
  );
}

ProviderContainer _actionsContainer(_FakeGateway gateway, {DateTime? today}) {
  return ProviderContainer(
    overrides: [
      streamSlippedGatewayProvider.overrideWithValue(gateway),
      streamSlippedClockProvider.overrideWithValue(
        () => today ?? DateTime(2026, 3, 30, 12),
      ),
    ],
  );
}

Future<List<SlippedItem>> _items(ProviderContainer container) async {
  final subscription = container.listen(
    streamSlippedItemsProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return container
      .read(streamSlippedItemsProvider.future)
      .timeout(const Duration(seconds: 2));
}

Task _task({
  required String id,
  String title = '',
  String? listId,
  String? dueDate,
  String? plannedDate,
  String? plannedStart,
  String? plannedEnd,
  int? completedAt,
  int? deletedAt,
}) {
  return Task(
    id: id,
    title: title,
    listId: listId,
    dueDate: dueDate,
    plannedDate: plannedDate,
    plannedStart: plannedStart,
    plannedEnd: plannedEnd,
    completedAt: completedAt,
    deletedAt: deletedAt,
    priority: 0,
    pinned: false,
    wontDo: false,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    dirty: false,
  );
}

TaskList _list(String id, {String? color}) {
  return TaskList(
    id: id,
    name: id,
    color: color,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    dirty: false,
  );
}

StreamSlippedTask _snapshot({
  String? dueDate,
  String? plannedDate,
  String? plannedStart,
  String? plannedEnd,
}) {
  return StreamSlippedTask(
    id: 't',
    listColorArgb: 0xFF000000,
    dueDate: dueDate,
    plannedDate: plannedDate,
    plannedStart: plannedStart,
    plannedEnd: plannedEnd,
  );
}

String _dayKey(DateTime day) => '${day.year}-${day.month}-${day.day}';

class _UpdateCall {
  const _UpdateCall(
    this.id,
    this.dueDate,
    this.plannedDate,
    this.plannedStart,
    this.plannedEnd,
  );

  final String id;
  final String? dueDate;
  final String? plannedDate;
  final String? plannedStart;
  final String? plannedEnd;
}

class _FakeGateway implements StreamSlippedGateway {
  _FakeGateway({this.task});

  StreamSlippedTask? task;
  Object? taskError;
  Object? completeError;
  Object? uncompleteError;
  Object? updateError;
  Object? deleteError;
  Object? restoreError;
  Object? rebuildError;

  final List<String> completeCalls = [];
  final List<String> uncompleteCalls = [];
  final List<_UpdateCall> updateCalls = [];
  final List<String> deleteCalls = [];
  final List<String> restoreCalls = [];
  final List<DateTime> rebuildDays = [];

  @override
  Future<StreamSlippedTask?> taskById(String id) async {
    if (taskError != null) throw taskError!;
    return task;
  }

  @override
  Future<void> completeTask(String id) async {
    if (completeError != null) throw completeError!;
    completeCalls.add(id);
  }

  @override
  Future<void> uncompleteTask(String id) async {
    if (uncompleteError != null) throw uncompleteError!;
    uncompleteCalls.add(id);
  }

  @override
  Future<void> updateTask(
    String id, {
    required String? dueDate,
    required String? plannedDate,
    required String? plannedStart,
    required String? plannedEnd,
  }) async {
    if (updateError != null) throw updateError!;
    updateCalls.add(
      _UpdateCall(id, dueDate, plannedDate, plannedStart, plannedEnd),
    );
  }

  @override
  Future<void> softDeleteTask(String id) async {
    if (deleteError != null) throw deleteError!;
    deleteCalls.add(id);
  }

  @override
  Future<void> restoreTask(String id) async {
    if (restoreError != null) throw restoreError!;
    restoreCalls.add(id);
  }

  @override
  Future<void> rebuildDay(DateTime localDay) async {
    if (rebuildError != null) throw rebuildError!;
    rebuildDays.add(DateTime(localDay.year, localDay.month, localDay.day));
  }
}
