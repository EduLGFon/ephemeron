import 'dart:io';

import 'package:drift/native.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

// Test-only Drift schema replay for the v11 -> v14 migration chain.
//
// The repository has no `drift_schemas/` snapshots (drift_dev schema export is
// not configured), so historical schemas are reconstructed from the migration
// code in `app_database.dart`:
//   v11 = current schema minus the v12 microsoft_account columns, the v13
//         task_occurrence_states table/index, and the v14 occurrence source
//         columns.
//   v12 = v11 + microsoft_account columns.
//   v13 = v12 + task_occurrence_states and its index.
//
// v11 is the earliest replayed version: v7 and v11 both recreate
// occurrence_cache, so occurrence cache rows cannot survive a pre-v11 replay by
// design. v4->v5 is covered by migration_v4_v5_case.dart and v6->current by
// migration_v7_v11_regression_case.dart. A full v1->v14 replay needs historical
// snapshots the repository does not keep, so the gap is v1->v11 plus the
// destructive occurrence_cache rebuilds in v7/v11.
//
// The fixture creates the v11 tables touched by v12-v14 and the tables whose
// rows are asserted. Migrations v12-v14 touch no other v11 table, so omitted
// tables cannot change the migration outcome.
void main() {
  for (final from in const [11, 12, 13]) {
    test(
      'replay v$from -> v14 adds later columns and preserves rows',
      () async {
        final dir = Directory.systemTemp.createTempSync(
          'ephemeron_v${from}_v14_',
        );
        final path = '${dir.path}/v$from.db';
        addTearDown(() {
          try {
            dir.deleteSync(recursive: true);
          } catch (_) {}
        });

        final seed = sqlite3.open(path);
        try {
          _createV11Schema(seed);
          if (from >= 12) _addMicrosoftColumns(seed);
          if (from >= 13) _createTaskOccurrenceStates(seed);
          _seedRows(seed, from);
          seed.execute('PRAGMA user_version = $from;');
        } finally {
          seed.close();
        }

        final db = AppDatabase.forTesting(NativeDatabase(File(path)));
        try {
          expect(db.schemaVersion, 14);
          await _verifyV14(db, from);
        } finally {
          await db.close();
        }
      },
    );
  }
}

Future<void> _verifyV14(AppDatabase db, int from) async {
  final calendar = await db
      .customSelect(
        "SELECT name, source, google_account, microsoft_account "
        "FROM calendars WHERE id = 'cal1'",
      )
      .getSingle();
  expect(calendar.read<String>('name'), 'Main');
  expect(calendar.read<String>('source'), 'google');
  expect(calendar.read<String?>('google_account'), 'g@example.com');
  expect(
    calendar.read<String?>('microsoft_account'),
    from >= 12 ? 'ms@example.com' : isNull,
  );

  final event = await db
      .customSelect(
        "SELECT title, rrule, recurring_master_id, original_start, "
        "google_account, microsoft_account FROM events WHERE id = 'ev1'",
      )
      .getSingle();
  expect(event.read<String>('title'), 'Weekly sync');
  expect(event.read<String?>('rrule'), 'FREQ=WEEKLY;BYDAY=MO');
  expect(event.read<String?>('recurring_master_id'), 'ev-master');
  expect(event.read<int?>('original_start'), 1000);
  expect(event.read<String?>('google_account'), 'g@example.com');
  expect(
    event.read<String?>('microsoft_account'),
    from >= 12 ? 'ms@example.com' : isNull,
  );

  final task = await db
      .customSelect(
        "SELECT title, rrule, due_date, planned_date, planned_start, "
        "planned_end, series_id, recurrence_key, google_account, "
        "microsoft_account FROM tasks WHERE id = 'task1'",
      )
      .getSingle();
  expect(task.read<String>('title'), 'Recurring task');
  expect(task.read<String?>('rrule'), 'FREQ=DAILY');
  expect(task.read<String?>('due_date'), '2026-01-05');
  expect(task.read<String?>('planned_date'), '2026-01-05');
  expect(task.read<String?>('planned_start'), '2026-01-05T09:00');
  expect(task.read<String?>('planned_end'), '2026-01-05T10:00');
  expect(task.read<String?>('series_id'), 'series1');
  expect(task.read<String?>('recurrence_key'), '2026-01-05');
  expect(task.read<String?>('google_account'), 'g@example.com');
  expect(
    task.read<String?>('microsoft_account'),
    from >= 12 ? 'ms@example.com' : isNull,
  );

  final note = await db
      .customSelect("SELECT title, body FROM notes WHERE id = 'note1'")
      .getSingle();
  expect(note.read<String>('title'), 'Note');
  expect(note.read<String?>('body'), 'Body');

  final habit = await db
      .customSelect("SELECT name, frequency FROM habits WHERE id = 'habit1'")
      .getSingle();
  expect(habit.read<String>('name'), 'Read');
  expect(habit.read<String>('frequency'), 'daily');

  final habitLog = await db
      .customSelect("SELECT done, amount FROM habit_logs WHERE id = 'log1'")
      .getSingle();
  expect(habitLog.read<int>('done'), 1);
  expect(habitLog.read<double>('amount'), 1.0);

  final occurrence = await db
      .customSelect(
        "SELECT title, source_type, source_label, source_account, day_key "
        "FROM occurrence_cache WHERE id = 'occ1'",
      )
      .getSingle();
  expect(occurrence.read<String>('title'), 'Old occurrence');
  expect(occurrence.read<String>('source_type'), 'event');
  expect(occurrence.read<String?>('source_label'), isNull);
  expect(occurrence.read<String?>('source_account'), isNull);
  expect(occurrence.read<String>('day_key'), '2026-01-05');

  final occurrenceColumns = await db
      .customSelect('PRAGMA table_info(occurrence_cache)')
      .get();
  final byName = {
    for (final row in occurrenceColumns) row.read<String>('name'): row,
  };
  for (final name in const ['source_label', 'source_account']) {
    expect(byName.keys, contains(name));
    expect(byName[name]!.read<int>('notnull'), 0);
  }

  final pending = await db
      .customSelect(
        "SELECT entity, entity_id, op, payload, scheduled_at "
        "FROM pending_operations WHERE id = 'pending1'",
      )
      .getSingle();
  expect(pending.read<String>('entity'), 'task');
  expect(pending.read<String>('entity_id'), 'task1');
  expect(pending.read<String>('op'), 'delete');
  expect(pending.read<String?>('payload'), '{}');
  expect(pending.read<int>('scheduled_at'), 5000);

  final outbox = await db
      .customSelect(
        "SELECT entity, entity_id, op, payload, attempts, next_try_at "
        "FROM outbox WHERE id = 'outbox1'",
      )
      .getSingle();
  expect(outbox.read<String>('entity'), 'task');
  expect(outbox.read<String>('entity_id'), 'task1');
  expect(outbox.read<String>('op'), 'update');
  expect(outbox.read<String?>('payload'), '{}');
  expect(outbox.read<int>('attempts'), 1);
  expect(outbox.read<int?>('next_try_at'), 6000);

  final occurrenceStateTables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='task_occurrence_states'",
      )
      .get();
  expect(occurrenceStateTables, isNotEmpty);
  final occurrenceStateIndexes = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_task_occurrence_states_series_date'",
      )
      .get();
  expect(occurrenceStateIndexes, isNotEmpty);

  if (from >= 13) {
    final state = await db
        .customSelect(
          "SELECT status, completed_at FROM task_occurrence_states "
          "WHERE series_id = 'series1' AND occurrence_date = '2026-01-05'",
        )
        .getSingle();
    expect(state.read<String>('status'), 'completed');
    expect(state.read<int?>('completed_at'), 2000);
  } else {
    final count = await db
        .customSelect('SELECT COUNT(*) AS count FROM task_occurrence_states')
        .getSingle();
    expect(count.read<int>('count'), 0);
  }
}

void _createV11Schema(Database db) {
  for (final statement in _v11Ddl) {
    db.execute(statement);
  }
}

void _addMicrosoftColumns(Database db) {
  db.execute('ALTER TABLE calendars ADD COLUMN microsoft_account TEXT;');
  db.execute('ALTER TABLE events ADD COLUMN microsoft_account TEXT;');
  db.execute('ALTER TABLE task_lists ADD COLUMN microsoft_account TEXT;');
  db.execute('ALTER TABLE tasks ADD COLUMN microsoft_account TEXT;');
}

void _createTaskOccurrenceStates(Database db) {
  db.execute('''
CREATE TABLE task_occurrence_states (
  series_id TEXT NOT NULL,
  occurrence_date TEXT NOT NULL,
  status TEXT NOT NULL,
  completed_at INTEGER,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (series_id, occurrence_date)
);
''');
  db.execute(
    'CREATE INDEX idx_task_occurrence_states_series_date '
    'ON task_occurrence_states(series_id, occurrence_date);',
  );
}

void _seedRows(Database db, int from) {
  db.execute('''
INSERT INTO calendars (
  id, remote_id, name, color, enabled, read_only, source, created_at,
  updated_at, dirty, remote_etag, google_account
) VALUES (
  'cal1', 'remote-cal', 'Main', '#123456', 1, 0, 'google', 1, 2, 0,
  'etag', 'g@example.com'
);
''');
  db.execute('''
INSERT INTO events (
  id, calendar_id, title, notes, start_utc, end_utc, is_all_day, rrule,
  recurring_master_id, original_start, status, color_id, create_meet,
  created_at, updated_at, google_account
) VALUES (
  'ev1', 'cal1', 'Weekly sync', 'Notes', 1000, 2000, 0,
  'FREQ=WEEKLY;BYDAY=MO', 'ev-master', 1000, 'confirmed', 'c1', 0, 1, 2,
  'g@example.com'
);
''');
  db.execute('''
INSERT INTO task_lists (
  id, name, sort_order, created_at, updated_at, google_account
) VALUES ('list1', 'Inbox', 0, 1, 2, 'g@example.com');
''');
  db.execute('''
INSERT INTO tasks (
  id, list_id, title, notes, priority, due_date, planned_date,
  planned_start, planned_end, series_id, recurrence_key, rrule, repeat_mode,
  created_at, updated_at, google_account
) VALUES (
  'task1', 'list1', 'Recurring task', 'Body', 2, '2026-01-05', '2026-01-05',
  '2026-01-05T09:00', '2026-01-05T10:00', 'series1', '2026-01-05',
  'FREQ=DAILY', 'due_date', 1, 2, 'g@example.com'
);
''');
  db.execute('''
INSERT INTO occurrence_cache (
  id, event_id, title, color_id, start_utc, end_utc, day_key, source_type
) VALUES (
  'occ1', 'ev1', 'Old occurrence', 'c1', 1000, 2000, '2026-01-05', 'event'
);
''');
  db.execute('''
INSERT INTO notes (id, title, body, created_at, updated_at)
VALUES ('note1', 'Note', 'Body', 1, 2);
''');
  db.execute('''
INSERT INTO habits (
  id, name, frequency, weekdays_mask, archived, created_at, updated_at
) VALUES ('habit1', 'Read', 'daily', 0, 0, 1, 2);
''');
  db.execute('''
INSERT INTO habit_logs (
  id, habit_id, day_key, amount, done, skipped, created_at, updated_at
) VALUES ('log1', 'habit1', '2026-01-05', 1.0, 1, 0, 1, 2);
''');
  db.execute('''
INSERT INTO pending_operations (
  id, entity, entity_id, op, payload, scheduled_at, created_at
) VALUES ('pending1', 'task', 'task1', 'delete', '{}', 5000, 1);
''');
  db.execute('''
INSERT INTO outbox (
  id, entity, entity_id, op, payload, attempts, next_try_at, created_at
) VALUES ('outbox1', 'task', 'task1', 'update', '{}', 1, 6000, 1);
''');

  if (from >= 12) {
    for (final table in const ['calendars', 'events', 'task_lists', 'tasks']) {
      db.execute(
        "UPDATE $table SET microsoft_account = 'ms@example.com' "
        "WHERE id IN ('cal1', 'ev1', 'list1', 'task1');",
      );
    }
  }

  if (from >= 13) {
    db.execute('''
INSERT INTO task_occurrence_states (
  series_id, occurrence_date, status, completed_at, updated_at
) VALUES ('series1', '2026-01-05', 'completed', 2000, 2);
''');
  }
}

const _v11Ddl = [
  '''
CREATE TABLE folders (
  id TEXT NOT NULL PRIMARY KEY,
  parent_id TEXT REFERENCES folders(id),
  name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);
''',
  '''
CREATE TABLE calendars (
  id TEXT NOT NULL PRIMARY KEY,
  remote_id TEXT,
  name TEXT NOT NULL,
  color TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  read_only INTEGER NOT NULL DEFAULT 0,
  source TEXT NOT NULL DEFAULT 'device',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  dirty INTEGER NOT NULL DEFAULT 0,
  remote_etag TEXT,
  google_account TEXT
);
''',
  '''
CREATE TABLE events (
  id TEXT NOT NULL PRIMARY KEY,
  calendar_id TEXT NOT NULL REFERENCES calendars(id),
  title TEXT NOT NULL DEFAULT '',
  notes TEXT,
  notes_overflow_note_id TEXT,
  location TEXT,
  start_utc INTEGER,
  end_utc INTEGER,
  start_date TEXT,
  end_date TEXT,
  is_all_day INTEGER NOT NULL DEFAULT 0,
  tz_id TEXT,
  end_tz_id TEXT,
  rrule TEXT,
  recurring_master_id TEXT,
  original_start INTEGER,
  status TEXT NOT NULL DEFAULT 'confirmed',
  color_id TEXT,
  meet_url TEXT,
  create_meet INTEGER NOT NULL DEFAULT 0,
  reminders TEXT,
  alarm_preset TEXT,
  visibility TEXT,
  transparency TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  dirty INTEGER NOT NULL DEFAULT 0,
  remote_id TEXT,
  remote_etag TEXT,
  google_account TEXT
);
''',
  '''
CREATE TABLE occurrence_cache (
  id TEXT NOT NULL PRIMARY KEY,
  event_id TEXT NOT NULL,
  title TEXT,
  color_id TEXT,
  start_utc INTEGER NOT NULL,
  end_utc INTEGER NOT NULL,
  day_key TEXT NOT NULL,
  source_type TEXT NOT NULL DEFAULT 'event'
);
''',
  '''
CREATE TABLE task_lists (
  id TEXT NOT NULL PRIMARY KEY,
  remote_id TEXT,
  name TEXT NOT NULL,
  color TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  dirty INTEGER NOT NULL DEFAULT 0,
  remote_etag TEXT,
  google_account TEXT
);
''',
  '''
CREATE TABLE tasks (
  id TEXT NOT NULL PRIMARY KEY,
  list_id TEXT REFERENCES task_lists(id),
  title TEXT NOT NULL DEFAULT '',
  notes TEXT,
  priority INTEGER NOT NULL DEFAULT 0,
  due_date TEXT,
  planned_date TEXT,
  planned_start TEXT,
  planned_end TEXT,
  series_id TEXT,
  recurrence_key TEXT,
  due_time INTEGER,
  duration_min INTEGER,
  rrule TEXT,
  repeat_mode TEXT,
  parent_id TEXT,
  pinned INTEGER NOT NULL DEFAULT 0,
  wont_do INTEGER NOT NULL DEFAULT 0,
  completed_at INTEGER,
  sort_order INTEGER NOT NULL DEFAULT 0,
  alarm_preset TEXT,
  reminders TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  dirty INTEGER NOT NULL DEFAULT 0,
  remote_id TEXT,
  remote_etag TEXT,
  google_account TEXT
);
''',
  '''
CREATE TABLE notes (
  id TEXT NOT NULL PRIMARY KEY,
  folder_id TEXT REFERENCES folders(id),
  title TEXT NOT NULL DEFAULT '',
  body TEXT,
  pinned INTEGER NOT NULL DEFAULT 0,
  linked_event_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  dirty INTEGER NOT NULL DEFAULT 0,
  remote_id TEXT,
  remote_etag TEXT
);
''',
  '''
CREATE TABLE habit_sections (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''',
  '''
CREATE TABLE habits (
  id TEXT NOT NULL PRIMARY KEY,
  section_id TEXT REFERENCES habit_sections(id),
  name TEXT NOT NULL,
  frequency TEXT NOT NULL DEFAULT 'daily',
  weekdays_mask INTEGER NOT NULL DEFAULT 0,
  weekly_target INTEGER,
  interval_days INTEGER,
  goal_type TEXT,
  goal_amount REAL,
  unit TEXT,
  increment REAL,
  goal_duration_days INTEGER,
  start_date TEXT,
  archived INTEGER NOT NULL DEFAULT 0,
  reminder_time TEXT,
  alarm_preset TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  dirty INTEGER NOT NULL DEFAULT 0,
  remote_id TEXT,
  remote_etag TEXT
);
''',
  '''
CREATE TABLE habit_logs (
  id TEXT NOT NULL PRIMARY KEY,
  habit_id TEXT NOT NULL REFERENCES habits(id),
  day_key TEXT NOT NULL,
  amount REAL NOT NULL DEFAULT 0,
  done INTEGER NOT NULL DEFAULT 0,
  skipped INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''',
  '''
CREATE TABLE pending_operations (
  id TEXT NOT NULL PRIMARY KEY,
  entity TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  op TEXT NOT NULL,
  payload TEXT,
  scheduled_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
''',
  '''
CREATE TABLE outbox (
  id TEXT NOT NULL PRIMARY KEY,
  entity TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  op TEXT NOT NULL,
  payload TEXT,
  attempts INTEGER NOT NULL DEFAULT 0,
  next_try_at INTEGER,
  last_error TEXT,
  created_at INTEGER NOT NULL
);
''',
];
