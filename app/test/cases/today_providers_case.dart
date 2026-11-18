import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart';
import 'package:ephemeron/features/today/application/today_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const String _today = '2026-11-18';
const String _yesterday = '2026-11-17';
const String _tomorrow = '2026-11-19';

Task _task({
  required String id,
  required String title,
  String? dueDate,
  String? plannedDate,
  String? plannedStart,
  int? dueTime,
  int priority = 0,
}) {
  return Task(
    id: id,
    title: title,
    priority: priority,
    dueDate: dueDate,
    plannedDate: plannedDate,
    plannedStart: plannedStart,
    dueTime: dueTime,
    pinned: false,
    wontDo: false,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    dirty: false,
  );
}

void main() {
  test('today range spans local midnight to next midnight', () {
    final now = DateTime(2026, 11, 18, 9, 30);
    final container = ProviderContainer(
      overrides: [deviceNowProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);

    final range = container.read(todayRangeProvider);
    expect(range.fromUtc, DateTime(2026, 11, 18).toUtc());
    expect(range.toUtc, DateTime(2026, 11, 19).toUtc());
    expect(container.read(todayKeyProvider), _today);
  });

  test('buckets today and overdue without duplicates', () {
    final tasks = <Task>[
      _task(id: 'a', title: 'Due today', dueDate: _today),
      _task(id: 'b', title: 'Planned today', plannedDate: _today),
      _task(id: 'c', title: 'Overdue', dueDate: _yesterday),
      _task(id: 'd', title: 'Overdue planned', plannedDate: _yesterday),
      _task(id: 'e', title: 'Tomorrow', dueDate: _tomorrow),
      _task(
        id: 'f',
        title: 'Today wins over overdue',
        dueDate: _today,
        plannedDate: _yesterday,
      ),
    ];

    final buckets = bucketTodayTasks(tasks, _today);
    expect(buckets.today.map((task) => task.id).toSet(), <String>{
      'a',
      'b',
      'f',
    });
    expect(buckets.overdue.map((task) => task.id).toSet(), <String>{'c', 'd'});
    expect(buckets.total, 5);
  });

  test('sorts by time, then title, then id', () {
    final tasks = <Task>[
      _task(id: 'late', title: 'Late', dueDate: _today, dueTime: 600),
      _task(
        id: 'planned',
        title: 'Planned',
        plannedDate: _today,
        plannedStart: '2026-11-18T09:00',
      ),
      _task(id: 'early', title: 'Early', dueDate: _today, dueTime: 540),
      _task(id: 'alpha', title: 'Alpha', dueDate: _today, dueTime: 540),
      _task(id: 'anytime', title: 'Anytime', dueDate: _today),
    ];

    final buckets = bucketTodayTasks(tasks, _today);
    expect(buckets.today.map((task) => task.id).toList(), <String>[
      'alpha',
      'early',
      'planned',
      'late',
      'anytime',
    ]);
  });

  test('visual priority maps persisted 4=P1 to visual 1', () {
    expect(visualTaskPriority(_task(id: 'x', title: 'x', priority: 0)), 0);
    expect(visualTaskPriority(_task(id: 'x', title: 'x', priority: 4)), 1);
    expect(visualTaskPriority(_task(id: 'x', title: 'x', priority: 1)), 4);
  });

  test('provider filters open tasks once per emission', () async {
    final tasks = <Task>[
      _task(id: 'today', title: 'Today', dueDate: _today),
      _task(id: 'overdue', title: 'Overdue', dueDate: _yesterday),
      _task(id: 'tomorrow', title: 'Tomorrow', dueDate: _tomorrow),
    ];
    final container = ProviderContainer(
      overrides: [
        deviceNowProvider.overrideWithValue(
          () => DateTime(2026, 11, 18, 9, 30),
        ),
        openTasksProvider.overrideWith((ref, _) => Stream.value(tasks)),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(todayTasksProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(openTasksProvider(null).future);
    final buckets = container.read(todayTasksProvider).requireValue;
    expect(buckets.today.single.id, 'today');
    expect(buckets.overdue.single.id, 'overdue');
  });
}
