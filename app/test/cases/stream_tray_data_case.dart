import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/stream/application/stream_tray.dart';
import 'package:ephemeron/features/stream/application/stream_tray_actions.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('streamTrayItemsProvider', () {
    test('includes only tasks with no date or time', () async {
      final container = _container(
        tasks: [
          _task('open', sortOrder: 2, dueTime: 540),
          _task(
            'plannedStart',
            sortOrder: 0,
            plannedStart: '2026-11-17T09:30',
            plannedEnd: '2026-11-17T10:00',
          ),
          _task('plannedDate', sortOrder: 0, plannedDate: '2026-11-17'),
          _task('dueDate', sortOrder: 0, dueDate: '2026-11-17'),
          _task(
            'empty',
            sortOrder: 3,
            plannedStart: '',
            plannedDate: '',
            dueDate: '',
          ),
        ],
      );

      final items = await container.read(streamTrayItemsProvider.future);

      expect(items.map((item) => item.id), ['open', 'empty']);
    });

    test(
      'maps list name and colour with caller-independent fallbacks',
      () async {
        final container = _container(
          tasks: [
            _task('a', title: 'A', listId: 'l1', sortOrder: 0),
            _task('b', title: 'B', listId: 'missing', sortOrder: 1),
            _task('c', title: 'C', sortOrder: 2),
            _task('d', title: 'D', listId: 'l2', sortOrder: 3),
            _task('e', title: 'E', listId: 'l2', sortOrder: 4),
          ],
          lists: [
            _list('l1', 'Work', color: '#123456'),
            _list('l2', 'Home'),
          ],
        );

        final items = await container.read(streamTrayItemsProvider.future);
        final byId = {for (final item in items) item.id: item};

        expect(byId['a']!.listId, 'l1');
        expect(byId['a']!.listName, 'Work');
        expect(byId['a']!.colorArgb, 0xFF123456);
        expect(byId['b']!.listName, 'missing');
        expect(byId['c']!.listId, '');
        expect(byId['c']!.listName, '');
        expect(byId['d']!.colorArgb, byId['e']!.colorArgb);
      },
    );

    test('sorts by sortOrder, title, then id', () async {
      final container = _container(
        tasks: [
          _task('b', title: 'B', sortOrder: 1),
          _task('a2', title: 'A', sortOrder: 1),
          _task('a1', title: 'A', sortOrder: 1),
          _task('first', title: 'Z', sortOrder: 0),
        ],
      );

      final items = await container.read(streamTrayItemsProvider.future);

      expect(items.map((item) => item.id), ['first', 'a1', 'a2', 'b']);
    });

    test('maps 500 unscheduled tasks', () async {
      final tasks = List.generate(
        500,
        (i) => _task(
          't$i',
          title: 'Task ${i.toString().padLeft(3, '0')}',
          sortOrder: 499 - i,
        ),
      );
      final container = _container(tasks: tasks);

      final items = await container.read(streamTrayItemsProvider.future);

      expect(items, hasLength(500));
      expect(items.first.id, 't499');
      expect(items.last.id, 't0');
    });

    test('keeps one item per duplicate id', () async {
      final container = _container(
        tasks: [
          _task('dup', title: 'Z', sortOrder: 0),
          _task('dup', title: 'A', sortOrder: 0),
          _task('unique', title: 'M', sortOrder: 1),
        ],
      );

      final items = await container.read(streamTrayItemsProvider.future);

      expect(items.map((item) => item.id), ['dup', 'unique']);
      expect(items.first.title, 'A');
    });

    test('empty input yields an empty list', () async {
      final container = _container(tasks: const []);

      final items = await container.read(streamTrayItemsProvider.future);

      expect(items, isEmpty);
    });
  });

  group('StreamTrayActions', () {
    test(
      'scheduleTask writes editor-compatible fields and rebuilds once',
      () async {
        final gateway = _FakeGateway();
        final container = _container(tasks: [_task('t1')], gateway: gateway);
        final actions = container.read(streamTrayActionsProvider);

        await actions.scheduleTask('t1', DateTime(2026, 11, 17, 9, 30));

        expect(gateway.updates, hasLength(1));
        final update = gateway.updates.single;
        expect(update.taskId, 't1');
        expect(update.plannedStart, '2026-11-17T09:30');
        expect(update.plannedEnd, '2026-11-17T10:00');
        expect(update.plannedDate, isNull);
        expect(update.dueTime, 9 * 60 + 30);
        expect(gateway.rebuiltDays, [DateTime(2026, 11, 17)]);
      },
    );

    test('missing task throws taskMissing', () async {
      final gateway = _FakeGateway();
      final container = _container(tasks: const [], gateway: gateway);
      final actions = container.read(streamTrayActionsProvider);

      await expectLater(
        actions.scheduleTask('missing', DateTime(2026, 11, 17, 9, 30)),
        throwsA(
          isA<StreamTrayException>().having(
            (error) => error.reason,
            'reason',
            StreamTrayFailure.taskMissing,
          ),
        ),
      );
      expect(gateway.updates, isEmpty);
    });

    test('already scheduled task throws alreadyScheduled', () async {
      final gateway = _FakeGateway();
      final container = _container(
        tasks: [
          _task(
            't1',
            plannedStart: '2026-11-17T09:30',
            plannedEnd: '2026-11-17T10:00',
          ),
        ],
        gateway: gateway,
      );
      final actions = container.read(streamTrayActionsProvider);

      await expectLater(
        actions.scheduleTask('t1', DateTime(2026, 11, 17, 11)),
        throwsA(
          isA<StreamTrayException>().having(
            (error) => error.reason,
            'reason',
            StreamTrayFailure.alreadyScheduled,
          ),
        ),
      );
      expect(gateway.updates, isEmpty);
    });

    test('gateway failure maps to updateFailed', () async {
      final failure = StateError('update failed');
      final gateway = _FakeGateway()..updateError = failure;
      final container = _container(tasks: [_task('t1')], gateway: gateway);
      final actions = container.read(streamTrayActionsProvider);

      await expectLater(
        actions.scheduleTask('t1', DateTime(2026, 11, 17, 9, 30)),
        throwsA(
          isA<StreamTrayException>()
              .having(
                (error) => error.reason,
                'reason',
                StreamTrayFailure.updateFailed,
              )
              .having((error) => error.cause, 'cause', same(failure)),
        ),
      );
      expect(gateway.rebuiltDays, isEmpty);
    });

    test('unscheduleTask clears planned fields and rebuilds once', () async {
      final gateway = _FakeGateway();
      final container = _container(
        tasks: [
          _task(
            't1',
            plannedStart: '2026-11-17T09:30',
            plannedEnd: '2026-11-17T10:00',
          ),
        ],
        gateway: gateway,
      );
      final actions = container.read(streamTrayActionsProvider);

      await actions.unscheduleTask('t1');

      expect(gateway.updates, hasLength(1));
      final update = gateway.updates.single;
      expect(update.taskId, 't1');
      expect(update.plannedStart, isNull);
      expect(update.plannedEnd, isNull);
      expect(update.plannedDate, isNull);
      expect(gateway.rebuiltDays, [DateTime(2026, 11, 17)]);
    });
  });
}

ProviderContainer _container({
  required List<Task> tasks,
  List<TaskList> lists = const <TaskList>[],
  StreamTrayGateway? gateway,
}) {
  final container = ProviderContainer(
    overrides: [
      openTasksProvider.overrideWith((ref, arg) => Stream.value(tasks)),
      taskListsProvider.overrideWith((ref) => Stream.value(lists)),
      streamTrayGatewayProvider.overrideWithValue(gateway ?? _FakeGateway()),
    ],
  );
  // A bare `.future` read does not keep a StreamProvider alive. Listening to
  // the tray provider also keeps its task stream subscribed, matching the UI.
  final subscription = container.listen(
    streamTrayItemsProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  addTearDown(container.dispose);
  return container;
}

Task _task(
  String id, {
  String? title,
  String? listId,
  int sortOrder = 0,
  String? plannedStart,
  String? plannedEnd,
  String? plannedDate,
  String? dueDate,
  int? dueTime,
}) {
  return Task(
    id: id,
    listId: listId,
    title: title ?? id,
    priority: 0,
    dueDate: dueDate,
    plannedDate: plannedDate,
    plannedStart: plannedStart,
    plannedEnd: plannedEnd,
    dueTime: dueTime,
    pinned: false,
    wontDo: false,
    sortOrder: sortOrder,
    createdAt: 0,
    updatedAt: 0,
    dirty: false,
  );
}

TaskList _list(String id, String name, {String? color}) {
  return TaskList(
    id: id,
    name: name,
    color: color,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    dirty: false,
  );
}

class _Update {
  const _Update({
    required this.taskId,
    required this.plannedStart,
    required this.plannedEnd,
    required this.plannedDate,
    required this.dueTime,
  });

  final String taskId;
  final String? plannedStart;
  final String? plannedEnd;
  final String? plannedDate;
  final int? dueTime;
}

class _FakeGateway implements StreamTrayGateway {
  final updates = <_Update>[];
  final rebuiltDays = <DateTime>[];
  Object? updateError;

  @override
  Future<void> updateTask(
    String taskId, {
    required String? plannedStart,
    required String? plannedEnd,
    required String? plannedDate,
    int? dueTime,
  }) async {
    final error = updateError;
    if (error != null) throw error;
    updates.add(
      _Update(
        taskId: taskId,
        plannedStart: plannedStart,
        plannedEnd: plannedEnd,
        plannedDate: plannedDate,
        dueTime: dueTime,
      ),
    );
  }

  @override
  Future<void> rebuildDay(DateTime day) async {
    rebuiltDays.add(day);
  }
}
