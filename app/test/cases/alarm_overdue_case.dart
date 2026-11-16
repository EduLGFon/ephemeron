import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ephemeron/core/time/time.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/alarms/data/alarm_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

String _tomorrowKey() {
  final t = DateTime.now().toUtc().add(const Duration(days: 1));
  return '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

Future<void> _insertRow(
  AppDatabase db, {
  required String id,
  required int fireAtUtc,
  required String state,
  required int requestCode,
  String kind = 'alarm',
  String preset = 'full_short',
}) {
  return db
      .into(db.alarmsIndex)
      .insert(
        AlarmsIndexCompanion.insert(
          id: id,
          sourceType: 'task',
          sourceId: '$id-task',
          fireAtUtc: fireAtUtc,
          requestCode: Value(requestCode),
          state: Value(state),
          kind: Value(kind),
          preset: Value(preset),
          title: Value('Alarm $id'),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ephemeron/alarms');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<int> cancelledCodes() => [
    for (final c in calls)
      if (c.method == 'cancel') c.arguments['requestCode'] as int,
  ];

  Future<AlarmsIndexData?> row(AppDatabase db, String id) {
    return (db.select(
      db.alarmsIndex,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  test('scheduled past becomes missed and cancels its native code', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _insertRow(
      db,
      id: 'past-scheduled',
      fireAtUtc: now - 5 * msPerMinute,
      state: 'scheduled',
      requestCode: 2001,
    );
    final settled = await AlarmRepository(db).reconcileOverdue(nowMs: now);
    expect(settled, 1);
    expect((await row(db, 'past-scheduled'))!.state, 'missed');
    expect(cancelledCodes(), contains(2001));
    expect(await AlarmRepository(db).dueAlarms(), isEmpty);
  });

  test('snoozed past becomes missed and cancels its native code', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _insertRow(
      db,
      id: 'past-snoozed',
      fireAtUtc: now - msPerMinute,
      state: 'snoozed',
      requestCode: 2002,
      kind: 'reminder',
      preset: 'notification',
    );
    final settled = await AlarmRepository(db).reconcileOverdue(nowMs: now);
    expect(settled, 1);
    expect((await row(db, 'past-snoozed'))!.state, 'missed');
    expect(cancelledCodes(), contains(2002));
  });

  test('future rows and a fresh fired row are untouched', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _insertRow(
      db,
      id: 'future-scheduled',
      fireAtUtc: now + 10 * msPerMinute,
      state: 'scheduled',
      requestCode: 3001,
    );
    await _insertRow(
      db,
      id: 'future-snoozed',
      fireAtUtc: now + 5 * msPerMinute,
      state: 'snoozed',
      requestCode: 3002,
    );
    await _insertRow(
      db,
      id: 'fresh-fired',
      fireAtUtc: now - 30 * 1000,
      state: 'fired',
      requestCode: 3003,
    );
    final settled = await AlarmRepository(db).reconcileOverdue(nowMs: now);
    expect(settled, 0);
    expect((await row(db, 'future-scheduled'))!.state, 'scheduled');
    expect((await row(db, 'future-snoozed'))!.state, 'snoozed');
    expect((await row(db, 'fresh-fired'))!.state, 'fired');
    expect(cancelledCodes(), isEmpty);
  });

  test('stale fired row becomes missed and is cancelled', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _insertRow(
      db,
      id: 'stale-fired',
      fireAtUtc: now - 3 * msPerMinute,
      state: 'fired',
      requestCode: 4001,
    );
    final settled = await AlarmRepository(db).reconcileOverdue(nowMs: now);
    expect(settled, 1);
    expect((await row(db, 'stale-fired'))!.state, 'missed');
    expect(cancelledCodes(), contains(4001));
  });

  test('only the newest fresh fired row survives', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _insertRow(
      db,
      id: 'older-fired',
      fireAtUtc: now - 90 * 1000,
      state: 'fired',
      requestCode: 5001,
    );
    await _insertRow(
      db,
      id: 'newest-fired',
      fireAtUtc: now - 30 * 1000,
      state: 'fired',
      requestCode: 5002,
    );
    final settled = await AlarmRepository(db).reconcileOverdue(nowMs: now);
    expect(settled, 1);
    expect((await row(db, 'older-fired'))!.state, 'missed');
    expect((await row(db, 'newest-fired'))!.state, 'fired');
    expect(cancelledCodes(), contains(5001));
    expect(cancelledCodes(), isNot(contains(5002)));
  });

  test('the verified active ring wins over a newer fired row', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _insertRow(
      db,
      id: 'active-fired',
      fireAtUtc: now - 90 * 1000,
      state: 'fired',
      requestCode: 6001,
    );
    await _insertRow(
      db,
      id: 'newer-fired',
      fireAtUtc: now - 30 * 1000,
      state: 'fired',
      requestCode: 6002,
    );
    final settled = await AlarmRepository(db)
        .reconcileOverdue(nowMs: now, activeRequestCode: 6001);
    expect(settled, 1);
    expect((await row(db, 'active-fired'))!.state, 'fired');
    expect((await row(db, 'newer-fired'))!.state, 'missed');
  });

  test('rebuildWindow never schedules past candidates', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _insertRow(
      db,
      id: 'overdue-before-rebuild',
      fireAtUtc: now - 5 * msPerMinute,
      state: 'scheduled',
      requestCode: 7001,
    );
    await TaskRepository(
      db,
    ).createTask(title: 'Tomorrow', dueDate: _tomorrowKey(), dueTime: 23 * 60);
    final repo = AlarmRepository(db);
    final planned = await repo.rebuildWindow(dueTomorrowEnabled: false);
    expect(planned, greaterThan(0));
    // The overdue row is settled, never preserved or rescheduled.
    expect(await row(db, 'overdue-before-rebuild'), null);
    final scheduled = await (db.select(
      db.alarmsIndex,
    )..where((a) => a.state.equals('scheduled'))).get();
    expect(scheduled, isNotEmpty);
    for (final r in scheduled) {
      expect(r.fireAtUtc, greaterThan(now));
    }
    for (final c in calls.where((c) => c.method == 'schedule')) {
      expect(c.arguments['fireAtUtcMs'] as int, greaterThan(now));
    }
    expect(await repo.dueAlarms(), isEmpty);
  });
}
