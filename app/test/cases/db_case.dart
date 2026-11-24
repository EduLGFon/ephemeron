import 'package:flutter_test/flutter_test.dart';

import 'package:ephemeron/data/drift/app_database.dart';

import '../support/test_fixtures.dart';

late AppDatabase db;

void main() {
  setUpAll(() async {
    db = newTestDb();
  });
  tearDownAll(() async {
    await db.close();
  });
  setUp(() async {
    await resetTestDb(db);
  });
  test('in-memory db creates schema and inserts calendar', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.calendars)
        .insert(
          CalendarsCompanion.insert(
            id: 'c1',
            name: 'Main',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final rows = await db.select(db.calendars).get();
    expect(rows.length, 1);
    expect(rows.first.name, 'Main');
  });

  test('fts tables exist', () async {
    final res = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='notes_fts'",
        )
        .get();
    expect(res, isNotEmpty);
  });

  test('schema version is 15', () async {
    expect(db.schemaVersion, 15);
  });

  test('events and tasks carry google_account', () async {
    for (final table in ['events', 'tasks']) {
      final cols = await db.customSelect('PRAGMA table_info($table)').get();
      expect(
        cols.map((r) => r.read<String>('name')),
        contains('google_account'),
      );
    }
  });

  test('tasks carry nullable planned_date added in v10', () async {
    final cols = await db.customSelect('PRAGMA table_info(tasks)').get();
    final planned = cols.where((r) => r.read<String>('name') == 'planned_date');
    expect(planned, hasLength(1));
    expect(planned.single.read<int>('notnull'), 0);
  });

  test('tasks carry v11 columns', () async {
    final cols = await db.customSelect('PRAGMA table_info(tasks)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    for (final c in [
      'planned_start',
      'planned_end',
      'series_id',
      'recurrence_key',
    ]) {
      expect(names, contains(c));
    }
    final occ = await db
        .customSelect('PRAGMA table_info(occurrence_cache)')
        .get();
    final occNames = occ.map((r) => r.read<String>('name')).toSet();
    expect(occNames, contains('source_type'));
  });

  test('v12 adds microsoft_account columns', () async {
    for (final table in ['calendars', 'events', 'task_lists', 'tasks']) {
      final cols = await db.customSelect('PRAGMA table_info($table)').get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('microsoft_account'));
    }
  });

  test('v14 adds occurrence source metadata columns', () async {
    final cols = await db
        .customSelect('PRAGMA table_info(occurrence_cache)')
        .get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['source_label', 'source_account']));
  });

  test('v15 adds nullable countdown link columns and index', () async {
    final cols = await db.customSelect('PRAGMA table_info(countdowns)').get();
    final byName = {for (final row in cols) row.read<String>('name'): row};
    for (final name in const ['linked_type', 'linked_id']) {
      expect(byName.keys, contains(name));
      expect(byName[name]!.read<int>('notnull'), 0);
    }
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_countdowns_linked'",
        )
        .get();
    expect(idx, isNotEmpty);
  });

  test('occurrence cache day index exists', () async {
    final res = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_occurrence_cache_day'",
        )
        .get();
    expect(res, isNotEmpty);
  });

  test('task occurrence states table and index exist', () async {
    final table = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='task_occurrence_states'",
        )
        .get();
    expect(table, isNotEmpty);
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_task_occurrence_states_series_date'",
        )
        .get();
    expect(idx, isNotEmpty);
  });
}
