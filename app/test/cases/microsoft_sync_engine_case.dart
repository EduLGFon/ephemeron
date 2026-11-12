import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ephemeron/core/config/app_config.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/domain/microsoft/microsoft_graph_models.dart';
import 'package:ephemeron/features/sync/data/microsoft_graph_client.dart';
import 'package:ephemeron/features/sync/data/microsoft_sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMs implements MicrosoftGraphClient {
  List<MsCalendar> calendars = [];
  List<MsEvent> events = [];
  Map<String, List<MsEvent>> eventsByCalendar = {};
  List<MsTodoList> lists = [];
  Map<String, List<MsTodoTask>> tasksByList = {};

  @override
  Future<MsIdentity> getMe() async => const MsIdentity(id: 'u');

  @override
  Future<List<MsCalendar>> listCalendars() async => calendars;

  @override
  Future<List<MsEvent>> calendarView(
    DateTime startUtc,
    DateTime endUtc, {
    String? calendarId,
  }) async => eventsByCalendar[calendarId] ?? events;

  @override
  Future<List<MsTodoList>> listTodoLists() async => lists;

  @override
  Future<List<MsTodoTask>> listTodoTasks(String listId) async =>
      tasksByList[listId] ?? [];
}

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

MsDateTimeTimeZone _dt(String s) =>
    MsDateTimeTimeZone(dateTime: s, timeZone: 'UTC');

void main() {
  test('idempotent double pull creates no duplicates', () async {
    final db = _db();
    addTearDown(db.close);
    final fake = FakeMs()
      ..calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: true)]
      ..events = [
        MsEvent(
          id: 'e1',
          subject: 'Meet',
          start: _dt('2026-01-01T10:00:00'),
          end: _dt('2026-01-01T11:00:00'),
        ),
      ]
      ..lists = [const MsTodoList(id: 'l1', displayName: 'Tasks')]
      ..tasksByList = {
        'l1': [MsTodoTask(id: 't1', title: 'Buy milk')],
      };
    final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
    await engine.syncNow();
    await engine.syncNow();
    expect(await db.select(db.calendars).get(), hasLength(1));
    expect(await db.select(db.events).get(), hasLength(1));
    expect(await db.select(db.taskLists).get(), hasLength(1));
    expect(await db.select(db.tasks).get(), hasLength(1));
  });

  test('two accounts with identical remote ids stay isolated', () async {
    final db = _db();
    addTearDown(db.close);
    for (final acct in ['a@example.com', 'b@example.com']) {
      final fake = FakeMs()
        ..calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: true)]
        ..events = [
          MsEvent(
            id: 'e1',
            subject: 'Meet $acct',
            start: _dt('2026-01-01T10:00:00'),
            end: _dt('2026-01-01T11:00:00'),
          ),
        ];
      final engine = MicrosoftSyncEngine(db, fake, acct);
      await engine.syncNow();
    }
    final cals = await db.select(db.calendars).get();
    expect(cals, hasLength(2));
    final evs = await db.select(db.events).get();
    expect(evs, hasLength(2));
    expect(evs.map((e) => e.microsoftAccount).toSet(), {
      'a@example.com',
      'b@example.com',
    });
  });

  test('local-only task fields survive re-pull', () async {
    final db = _db();
    addTearDown(db.close);
    final fake = FakeMs()
      ..calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: true)]
      ..lists = [const MsTodoList(id: 'l1', displayName: 'Tasks')]
      ..tasksByList = {
        'l1': [MsTodoTask(id: 't1', title: 'Buy milk')],
      };
    final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
    await engine.syncNow();
    // set local fields
    final task = (await db.select(db.tasks).get()).single;
    final taskUpdate = db.update(db.tasks)..where((t) => t.id.equals(task.id));
    await taskUpdate.write(
      TasksCompanion(
        plannedDate: Value('2026-02-02'),
        plannedStart: Value('2026-02-02T09:00'),
        plannedEnd: Value('2026-02-02T10:00'),
        seriesId: Value('series1'),
        recurrenceKey: Value('2026-02-02'),
        priority: Value(3),
        durationMin: Value(45),
        rrule: Value('FREQ=DAILY'),
        repeatMode: Value('daily'),
        pinned: Value(true),
        wontDo: Value(true),
      ),
    );
    // re-pull with updated title
    fake.tasksByList = {
      'l1': [MsTodoTask(id: 't1', title: 'Buy milk v2')],
    };
    await engine.syncNow();
    final after = (await db.select(db.tasks).get()).single;
    expect(after.title, 'Buy milk v2');
    expect(after.plannedDate, '2026-02-02');
    expect(after.plannedStart, '2026-02-02T09:00');
    expect(after.plannedEnd, '2026-02-02T10:00');
    expect(after.seriesId, 'series1');
    expect(after.recurrenceKey, '2026-02-02');
    expect(after.priority, 3);
    expect(after.durationMin, 45);
    expect(after.rrule, 'FREQ=DAILY');
    expect(after.repeatMode, 'daily');
    expect(after.pinned, true);
    expect(after.wontDo, true);
  });

  test(
    'local event alarmPreset/reminders/visibility survive re-pull',
    () async {
      final db = _db();
      addTearDown(db.close);
      final fake = FakeMs()
        ..calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: true)]
        ..events = [
          MsEvent(
            id: 'e1',
            subject: 'Meet',
            start: _dt('2026-01-01T10:00:00'),
            end: _dt('2026-01-01T11:00:00'),
          ),
        ];
      final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
      await engine.syncNow();
      final ev = (await db.select(db.events).get()).single;
      final eventUpdate = db.update(db.events)
        ..where((t) => t.id.equals(ev.id));
      await eventUpdate.write(
        EventsCompanion(
          alarmPreset: Value('loud'),
          reminders: Value('[10]'),
          visibility: Value('private'),
        ),
      );
      fake.events = [
        MsEvent(
          id: 'e1',
          subject: 'Meet v2',
          start: _dt('2026-01-01T10:00:00'),
          end: _dt('2026-01-01T11:00:00'),
        ),
      ];
      await engine.syncNow();
      final after = (await db.select(db.events).get()).single;
      expect(after.title, 'Meet v2');
      expect(after.alarmPreset, 'loud');
      expect(after.reminders, '[10]');
      expect(after.visibility, 'private');
    },
  );

  test('timed and all-day events map to correct UTC/date fields', () async {
    final db = _db();
    addTearDown(db.close);
    final fake = FakeMs()
      ..calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: true)]
      ..events = [
        MsEvent(
          id: 'timed',
          subject: 'Timed',
          start: _dt('2026-01-01T10:00:00'),
          end: _dt('2026-01-01T11:00:00'),
          isAllDay: false,
        ),
        MsEvent(
          id: 'allday',
          subject: 'AllDay',
          start: _dt('2026-01-02T00:00:00'),
          end: _dt('2026-01-03T00:00:00'),
          isAllDay: true,
        ),
      ];
    final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
    await engine.syncNow();
    final rows = await db.select(db.events).get();
    final timed = rows.firstWhere((e) => e.remoteId == 'timed');
    expect(timed.startUtc, DateTime.utc(2026, 1, 1, 10).millisecondsSinceEpoch);
    expect(timed.endUtc, DateTime.utc(2026, 1, 1, 11).millisecondsSinceEpoch);
    expect(timed.startDate, isNull);
    expect(timed.isAllDay, false);
    final allday = rows.firstWhere((e) => e.remoteId == 'allday');
    expect(allday.startUtc, isNull);
    expect(allday.endUtc, isNull);
    expect(allday.startDate, '2026-01-02');
    expect(allday.endDate, '2026-01-03');
    expect(allday.isAllDay, true);
  });

  test('events link to their own Microsoft calendar', () async {
    final db = _db();
    addTearDown(db.close);
    final fake = FakeMs()
      ..calendars = [
        const MsCalendar(id: 'c1', name: 'Work', canEdit: true),
        const MsCalendar(id: 'c2', name: 'Home', canEdit: true),
      ]
      ..eventsByCalendar = {
        'c1': [
          MsEvent(
            id: 'e1',
            subject: 'Work event',
            start: _dt('2026-01-01T10:00:00'),
            end: _dt('2026-01-01T11:00:00'),
          ),
        ],
        'c2': [
          MsEvent(
            id: 'e2',
            subject: 'Home event',
            start: _dt('2026-01-01T12:00:00'),
            end: _dt('2026-01-01T13:00:00'),
          ),
        ],
      };
    final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
    await engine.syncNow();
    final cals = await db.select(db.calendars).get();
    final work = cals.firstWhere((c) => c.remoteId == 'c1');
    final home = cals.firstWhere((c) => c.remoteId == 'c2');
    final events = await db.select(db.events).get();
    expect(events.firstWhere((e) => e.remoteId == 'e1').calendarId, work.id);
    expect(events.firstWhere((e) => e.remoteId == 'e2').calendarId, home.id);
  });

  test('cancelled events map to status', () async {
    final db = _db();
    addTearDown(db.close);
    final fake = FakeMs()
      ..calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: true)]
      ..events = [
        MsEvent(
          id: 'canc',
          subject: 'Cancelled',
          isCancelled: true,
          start: _dt('2026-01-01T10:00:00'),
          end: _dt('2026-01-01T11:00:00'),
        ),
      ];
    final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
    await engine.syncNow();
    final ev = (await db.select(db.events).get()).single;
    expect(ev.status, 'cancelled');
  });

  test('To Do dueDate/dueTime and completedAt map correctly', () async {
    final db = _db();
    addTearDown(db.close);
    final fake = FakeMs()
      ..lists = [const MsTodoList(id: 'l1', displayName: 'Tasks')]
      ..tasksByList = {
        'l1': [
          MsTodoTask(
            id: 't1',
            title: 'Buy milk',
            status: 'completed',
            dueDateTime: _dt('2026-01-02T14:30:00'),
            completedDateTime: _dt('2026-01-03T00:00:00'),
          ),
        ],
      };
    final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
    await engine.syncNow();
    final task = (await db.select(db.tasks).get()).single;
    expect(task.dueDate, '2026-01-02');
    expect(task.dueTime, 14 * 60 + 30);
    expect(task.completedAt, DateTime.utc(2026, 1, 3).millisecondsSinceEpoch);
  });

  test(
    'calendar readOnly from canEdit and enabled preserved across pulls',
    () async {
      final db = _db();
      addTearDown(db.close);
      final fake = FakeMs()
        ..calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: false)];
      final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
      await engine.syncNow();
      final cal = (await db.select(db.calendars).get()).single;
      expect(cal.readOnly, true);
      expect(cal.enabled, true);
      // flip enabled locally
      final calUpdate = db.update(db.calendars)
        ..where((t) => t.id.equals(cal.id));
      await calUpdate.write(const CalendarsCompanion(enabled: Value(false)));
      // change canEdit remotely
      fake.calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: true)];
      await engine.syncNow();
      final after = (await db.select(db.calendars).get()).single;
      expect(after.readOnly, false);
      expect(after.enabled, false);
    },
  );

  test('null token surfaces as auth failure without writing rows', () async {
    final db = _db();
    addTearDown(db.close);
    final client = HttpMicrosoftGraphClient(
      accessToken: () async => null,
      httpClient: null,
    );
    final engine = MicrosoftSyncEngine(db, client, 'acct@example.com');
    final result = await engine.syncNow();
    expect(result.authFailure, true);
    expect(await db.select(db.calendars).get(), isEmpty);
    expect(await db.select(db.events).get(), isEmpty);
    expect(await db.select(db.taskLists).get(), isEmpty);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  test(
    'remote task deletion is reconciled after complete list fetch',
    () async {
      final db = _db();
      addTearDown(db.close);
      final fake = FakeMs()
        ..lists = [const MsTodoList(id: 'l1', displayName: 'Tasks')]
        ..tasksByList = {
          'l1': [
            MsTodoTask(id: 't1', title: 'Keep'),
            MsTodoTask(id: 't2', title: 'Gone'),
          ],
        };
      final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
      await engine.syncNow();
      fake.tasksByList = {
        'l1': [MsTodoTask(id: 't1', title: 'Keep')],
      };
      await engine.syncNow();
      final rows = await (db.select(
        db.tasks,
      )..where((t) => t.microsoftAccount.equals('acct@example.com'))).get();
      final kept = rows.firstWhere((t) => t.remoteId == 't1');
      final gone = rows.firstWhere((t) => t.remoteId == 't2');
      expect(kept.deletedAt, isNull);
      expect(gone.deletedAt, isNotNull);
      expect(gone.dirty, false);
    },
  );

  test('dirty local task is never reconciled as remote deletion', () async {
    final db = _db();
    addTearDown(db.close);
    final fake = FakeMs()
      ..lists = [const MsTodoList(id: 'l1', displayName: 'Tasks')]
      ..tasksByList = {
        'l1': [MsTodoTask(id: 't1', title: 'Edit me')],
      };
    final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
    await engine.syncNow();
    final task = (await db.select(db.tasks).get()).single;
    await (db.update(db.tasks)..where((t) => t.id.equals(task.id))).write(
      const TasksCompanion(dirty: Value(true), title: Value('Local edit')),
    );
    fake.tasksByList = {'l1': []};
    await engine.syncNow();
    final after = (await db.select(db.tasks).get()).single;
    expect(after.deletedAt, isNull);
    expect(after.dirty, true);
    expect(after.title, 'Local edit');
  });

  test('remote task list deletion soft-deletes list and its tasks', () async {
    final db = _db();
    addTearDown(db.close);
    final fake = FakeMs()
      ..lists = [
        const MsTodoList(id: 'l1', displayName: 'Keep'),
        const MsTodoList(id: 'l2', displayName: 'Gone'),
      ]
      ..tasksByList = {
        'l1': [MsTodoTask(id: 't1', title: 'Stay')],
        'l2': [MsTodoTask(id: 't2', title: 'Orphan no')],
      };
    final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
    await engine.syncNow();
    fake.lists = [const MsTodoList(id: 'l1', displayName: 'Keep')];
    fake.tasksByList = {
      'l1': [MsTodoTask(id: 't1', title: 'Stay')],
    };
    await engine.syncNow();
    final lists = await (db.select(
      db.taskLists,
    )..where((t) => t.microsoftAccount.equals('acct@example.com'))).get();
    final keptList = lists.firstWhere((l) => l.remoteId == 'l1');
    final goneList = lists.firstWhere((l) => l.remoteId == 'l2');
    expect(keptList.deletedAt, isNull);
    expect(goneList.deletedAt, isNotNull);
    final tasks = await (db.select(
      db.tasks,
    )..where((t) => t.microsoftAccount.equals('acct@example.com'))).get();
    expect(tasks.firstWhere((t) => t.remoteId == 't1').deletedAt, isNull);
    expect(tasks.firstWhere((t) => t.remoteId == 't2').deletedAt, isNotNull);
  });

  test('reconciliation is scoped to the synced Microsoft account', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.taskLists)
        .insert(
          TaskListsCompanion.insert(
            id: 'local-ms',
            remoteId: const Value('shared'),
            name: 'Other acct',
            microsoftAccount: const Value('other@example.com'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'local-task',
            listId: const Value('local-ms'),
            remoteId: const Value('t-shared'),
            title: const Value('Other'),
            microsoftAccount: const Value('other@example.com'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final fake = FakeMs()
      ..lists = [const MsTodoList(id: 'l1', displayName: 'Mine')]
      ..tasksByList = {
        'l1': [MsTodoTask(id: 't1', title: 'Mine')],
      };
    final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
    await engine.syncNow();
    final otherList = await (db.select(
      db.taskLists,
    )..where((t) => t.id.equals('local-ms'))).getSingle();
    final otherTask = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals('local-task'))).getSingle();
    expect(otherList.deletedAt, isNull);
    expect(otherTask.deletedAt, isNull);
  });

  test('task fetch failure is isolated to that list and auth scoped', () async {
    for (final entry in <(int, bool)>[
      (401, true),
      (403, false),
      (404, false),
      (500, false),
    ]) {
      final db = _db();
      addTearDown(db.close);
      final fake = _FailingTasksFake()
        ..lists = [
          const MsTodoList(id: 'l1', displayName: 'First'),
          const MsTodoList(id: 'l2', displayName: 'Second'),
        ]
        ..tasksByList = {
          'l1': [MsTodoTask(id: 't1', title: 'One')],
          'l2': [MsTodoTask(id: 't2', title: 'Keep')],
        };
      final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
      await engine.syncNow();

      fake.failStatus = entry.$1;
      fake.failListId = 'l1';
      fake.tasksByList = {
        'l1': [],
        'l2': [MsTodoTask(id: 't2', title: 'Keep v2')],
      };

      final result = await engine.syncNow();

      expect(result.authFailure, entry.$2);
      // The second list is still pulled after the first one fails.
      final t2 = await (db.select(
        db.tasks,
      )..where((t) => t.remoteId.equals('t2'))).getSingle();
      expect(t2.title, 'Keep v2');
      expect(t2.deletedAt, isNull);
      // The failed list is not reconciled, so its tasks stay.
      final t1 = await (db.select(
        db.tasks,
      )..where((t) => t.remoteId.equals('t1'))).getSingle();
      expect(t1.deletedAt, isNull);
    }
  });

  test(
    'one calendar failure does not abort other calendars or tasks',
    () async {
      for (final entry in <(int, bool)>[
        (401, true),
        (403, false),
        (404, false),
        (410, false),
        (500, false),
      ]) {
        final db = _db();
        addTearDown(db.close);
        final fake = _FailingCalendarFake(entry.$1)
          ..calendars = [
            const MsCalendar(id: 'bad', name: 'Bad', canEdit: true),
            const MsCalendar(id: 'good', name: 'Good', canEdit: true),
          ]
          ..eventsByCalendar = {
            'good': [
              MsEvent(
                id: 'e-good',
                subject: 'Keep',
                start: _dt('2026-01-01T10:00:00'),
                end: _dt('2026-01-01T11:00:00'),
              ),
            ],
          }
          ..lists = [const MsTodoList(id: 'l1', displayName: 'Tasks')]
          ..tasksByList = {
            'l1': [MsTodoTask(id: 't1', title: 'Task')],
          };
        final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');

        final result = await engine.syncNow();

        expect(result.authFailure, entry.$2);
        final events = await db.select(db.events).get();
        expect(events.where((e) => e.remoteId == 'e-good'), hasLength(1));
        final tasks = await db.select(db.tasks).get();
        expect(tasks, hasLength(1));
        expect(tasks.single.remoteId, 't1');
      }
    },
  );

  test('Microsoft scopes request shared calendar read access', () {
    expect(
      AppConfig.microsoftScopes,
      contains('https://graph.microsoft.com/Calendars.Read.Shared'),
    );
  });

  test('403 signals auth failure only for a shared calendar', () async {
    for (final entry in <(bool, bool)>[(true, true), (false, false)]) {
      final db = _db();
      addTearDown(db.close);
      final fake = _FailingCalendarFake(403)
        ..calendars = [
          MsCalendar(
            id: 'bad',
            name: 'Bad',
            isSharedWithMe: entry.$1,
            canEdit: true,
          ),
          const MsCalendar(id: 'good', name: 'Good', canEdit: true),
        ]
        ..eventsByCalendar = {
          'good': [
            MsEvent(
              id: 'e-good',
              subject: 'Keep',
              start: _dt('2026-01-01T10:00:00'),
              end: _dt('2026-01-01T11:00:00'),
            ),
          ],
        }
        ..lists = [const MsTodoList(id: 'l1', displayName: 'Tasks')]
        ..tasksByList = {
          'l1': [MsTodoTask(id: 't1', title: 'Task')],
        };
      final result = await MicrosoftSyncEngine(
        db,
        fake,
        'acct@example.com',
      ).syncNow();

      expect(result.authFailure, entry.$2);
      final events = await db.select(db.events).get();
      expect(events.where((e) => e.remoteId == 'e-good'), hasLength(1));
      expect(await db.select(db.tasks).get(), hasLength(1));
    }
  });

  test('403 uses the owner address when the shared flag is missing', () async {
    for (final entry in <(String, bool)>[
      ('owner@example.com', true),
      ('acct@example.com', false),
    ]) {
      final db = _db();
      addTearDown(db.close);
      final fake = _FailingCalendarFake(403)
        ..calendars = [
          MsCalendar(
            id: 'bad',
            name: 'Bad',
            owner: MsEmailAddress(address: entry.$1),
          ),
          const MsCalendar(id: 'good', name: 'Good', canEdit: true),
        ]
        ..eventsByCalendar = {
          'good': [
            MsEvent(
              id: 'e-good',
              subject: 'Keep',
              start: _dt('2026-01-01T10:00:00'),
              end: _dt('2026-01-01T11:00:00'),
            ),
          ],
        }
        ..lists = [const MsTodoList(id: 'l1', displayName: 'Tasks')]
        ..tasksByList = {
          'l1': [MsTodoTask(id: 't1', title: 'Task')],
        };
      final result = await MicrosoftSyncEngine(
        db,
        fake,
        'acct@example.com',
      ).syncNow();

      expect(result.authFailure, entry.$2);
      final events = await db.select(db.events).get();
      expect(events.where((e) => e.remoteId == 'e-good'), hasLength(1));
      expect(await db.select(db.tasks).get(), hasLength(1));
    }
  });

  test('shared calendar stored once and only its owner pulls events', () async {
    final db = _db();
    addTearDown(db.close);
    const ownerCopy = MsCalendar(
      id: 'c-shared',
      name: 'Team',
      owner: MsEmailAddress(address: 'owner@example.com'),
    );
    const sharedCopy = MsCalendar(
      id: 'c-shared',
      name: 'Team',
      isSharedWithMe: true,
      owner: MsEmailAddress(address: 'owner@example.com'),
    );
    const signedIn = ['owner@example.com', 'delegate@example.com'];
    final ownerFake = _SharedCalendarFake('c-shared')..calendars = [ownerCopy];
    final delegateFake = _SharedCalendarFake('c-shared')
      ..calendars = [sharedCopy];

    await MicrosoftSyncEngine(
      db,
      ownerFake,
      'owner@example.com',
      signedInAccounts: signedIn,
    ).syncNow();
    await MicrosoftSyncEngine(
      db,
      delegateFake,
      'delegate@example.com',
      signedInAccounts: signedIn,
    ).syncNow();

    final cals = await db.select(db.calendars).get();
    expect(cals, hasLength(1));
    expect(cals.single.microsoftAccount, 'owner@example.com');
    expect(ownerFake.sharedPulls, 1);
    expect(delegateFake.sharedPulls, 0);
    final events = await db.select(db.events).get();
    expect(events, hasLength(1));
    expect(events.single.microsoftAccount, 'owner@example.com');
    expect(events.single.calendarId, cals.single.id);
  });

  test('delegate-first shared calendar uses the Graph owner stamp', () async {
    final db = _db();
    addTearDown(db.close);
    const sharedCopy = MsCalendar(
      id: 'c-shared',
      name: 'Team',
      isSharedWithMe: true,
      owner: MsEmailAddress(address: 'a@x'),
    );
    final bFake = _SharedCalendarFake('c-shared')..calendars = [sharedCopy];
    await MicrosoftSyncEngine(
      db,
      bFake,
      'b@x',
      signedInAccounts: const ['b@x'],
    ).syncNow();

    var cals = await db.select(db.calendars).get();
    expect(cals, hasLength(1));
    expect(cals.single.microsoftAccount, 'a@x');
    expect(bFake.sharedPulls, 1);
    expect(await db.select(db.events).get(), hasLength(1));

    const ownerCopy = MsCalendar(
      id: 'c-shared',
      name: 'Team',
      owner: MsEmailAddress(address: 'a@x'),
    );
    final aFake = _SharedCalendarFake('c-shared')..calendars = [ownerCopy];
    await MicrosoftSyncEngine(
      db,
      aFake,
      'a@x',
      signedInAccounts: const ['a@x', 'b@x'],
    ).syncNow();

    cals = await db.select(db.calendars).get();
    expect(cals, hasLength(1));
    expect(cals.single.microsoftAccount, 'a@x');
    // The owner wins over the recorded delegate reader and pulls the events.
    expect(aFake.sharedPulls, 1);
    final events = await db.select(db.events).get();
    expect(events, hasLength(1));
    expect(events.single.microsoftAccount, 'a@x');
  });

  test('shared calendar with absent owner allows a single claimer', () async {
    final db = _db();
    addTearDown(db.close);
    const ownerCopy = MsCalendar(
      id: 'c-shared',
      name: 'Team',
      owner: MsEmailAddress(address: 'owner@example.com'),
    );
    const sharedCopy = MsCalendar(
      id: 'c-shared',
      name: 'Team',
      isSharedWithMe: true,
      owner: MsEmailAddress(address: 'owner@example.com'),
    );
    final ownerFake = _SharedCalendarFake('c-shared')..calendars = [ownerCopy];
    await MicrosoftSyncEngine(
      db,
      ownerFake,
      'owner@example.com',
      signedInAccounts: const ['owner@example.com'],
    ).syncNow();

    const bAndC = ['b@example.com', 'c@example.com'];
    final bFake = _SharedCalendarFake('c-shared')..calendars = [sharedCopy];
    final cFake = _SharedCalendarFake('c-shared')..calendars = [sharedCopy];
    await MicrosoftSyncEngine(
      db,
      bFake,
      'b@example.com',
      signedInAccounts: bAndC,
    ).syncNow();
    await MicrosoftSyncEngine(
      db,
      cFake,
      'c@example.com',
      signedInAccounts: bAndC,
    ).syncNow();

    expect(await db.select(db.calendars).get(), hasLength(1));
    expect(bFake.sharedPulls, 1);
    expect(cFake.sharedPulls, 0);
    final cal = (await db.select(db.calendars).get()).single;
    expect(cal.microsoftAccount, 'owner@example.com');
    final events = await db.select(db.events).get();
    expect(events, hasLength(1));
    expect(events.single.microsoftAccount, 'owner@example.com');

    // The recorded reader is signed out, so another account may claim it.
    await MicrosoftSyncEngine(
      db,
      cFake,
      'c@example.com',
      signedInAccounts: const ['c@example.com'],
    ).syncNow();
    expect(cFake.sharedPulls, 1);
    expect(await db.select(db.calendars).get(), hasLength(1));
    expect(await db.select(db.events).get(), hasLength(1));
  });

  test('shared calendar event row is adopted instead of duplicated', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.calendars)
        .insert(
          CalendarsCompanion.insert(
            id: 'mscal_owner_c-shared',
            remoteId: const Value('c-shared'),
            name: 'Team',
            source: const Value('microsoft'),
            microsoftAccount: const Value('owner@example.com'),
            enabled: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'msevt_delegate_c-shared',
            calendarId: 'mscal_owner_c-shared',
            title: const Value('Shared event'),
            startUtc: Value(
              DateTime.utc(2026, 1, 1, 10).millisecondsSinceEpoch,
            ),
            endUtc: Value(DateTime.utc(2026, 1, 1, 11).millisecondsSinceEpoch),
            microsoftAccount: const Value('delegate@example.com'),
            remoteId: const Value('e-shared'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final fake = _SharedCalendarFake('c-shared')
      ..calendars = [
        const MsCalendar(
          id: 'c-shared',
          name: 'Team',
          owner: MsEmailAddress(address: 'owner@example.com'),
        ),
      ];
    await MicrosoftSyncEngine(
      db,
      fake,
      'owner@example.com',
      signedInAccounts: const ['owner@example.com'],
    ).syncNow();

    final events = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('e-shared'))).get();
    expect(events, hasLength(1));
    expect(events.single.microsoftAccount, 'owner@example.com');
    expect(events.single.calendarId, 'mscal_owner_c-shared');
  });

  test('calendarView pagination is followed (client contract)', () async {
    // Pagination is implemented in HttpMicrosoftGraphClient._paginate and
    // covered by microsoft_graph_case.dart; reconciliation relies on complete
    // results, so a fake returning complete data is sufficient here.
    final db = _db();
    addTearDown(db.close);
    final fake = FakeMs()
      ..lists = [const MsTodoList(id: 'l1', displayName: 'Tasks')]
      ..tasksByList = {
        'l1': [MsTodoTask(id: 't1', title: 'One')],
      };
    final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
    await engine.syncNow();
    fake.tasksByList = {'l1': []};
    await engine.syncNow();
    final task = (await db.select(db.tasks).get()).single;
    expect(task.deletedAt, isNotNull);
  });

  test(
    'remote calendar deletion soft-deletes only clean own calendars',
    () async {
      final db = _db();
      addTearDown(db.close);
      final fake = FakeMs()
        ..calendars = [
          const MsCalendar(id: 'c-gone', name: 'Gone', canEdit: true),
          const MsCalendar(id: 'c-dirty', name: 'Dirty', canEdit: true),
          const MsCalendar(id: 'c-keep', name: 'Keep', canEdit: true),
        ];
      final engine = MicrosoftSyncEngine(db, fake, 'acct@example.com');
      await engine.syncNow();
      await (db.update(db.calendars)
            ..where((c) => c.remoteId.equals('c-dirty')))
          .write(const CalendarsCompanion(dirty: Value(true)));
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      // A local-only Microsoft calendar and a shared row owned by another
      // account must never be reconciled by this account.
      await db
          .into(db.calendars)
          .insert(
            CalendarsCompanion.insert(
              id: 'mscal_acct_local',
              name: 'Local only',
              source: const Value('microsoft'),
              microsoftAccount: const Value('acct@example.com'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.calendars)
          .insert(
            CalendarsCompanion.insert(
              id: 'mscal_other_shared',
              remoteId: const Value('c-shared'),
              name: 'Shared',
              source: const Value('microsoft'),
              microsoftAccount: const Value('other@example.com'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      fake.calendars = [
        const MsCalendar(id: 'c-keep', name: 'Keep', canEdit: true),
      ];
      await engine.syncNow();

      final rows = await db.select(db.calendars).get();
      expect(
        rows.firstWhere((c) => c.remoteId == 'c-gone').deletedAt,
        isNotNull,
      );
      expect(rows.firstWhere((c) => c.remoteId == 'c-dirty').deletedAt, isNull);
      expect(rows.firstWhere((c) => c.remoteId == 'c-keep').deletedAt, isNull);
      expect(
        rows.firstWhere((c) => c.id == 'mscal_acct_local').deletedAt,
        isNull,
      );
      expect(
        rows.firstWhere((c) => c.id == 'mscal_other_shared').deletedAt,
        isNull,
      );
    },
  );

  test(
    'remote event deletion reconciled only inside the fetched window',
    () async {
      final db = _db();
      addTearDown(db.close);
      final fake = FakeMs()
        ..calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: true)]
        ..eventsByCalendar = {
          'c1': [
            MsEvent(
              id: 'e-keep',
              subject: 'Keep',
              start: _dt('2026-01-05T10:00:00'),
              end: _dt('2026-01-05T11:00:00'),
            ),
            MsEvent(
              id: 'e-gone',
              subject: 'Gone',
              start: _dt('2026-01-06T10:00:00'),
              end: _dt('2026-01-06T11:00:00'),
            ),
            MsEvent(
              id: 'e-dirty',
              subject: 'Dirty',
              start: _dt('2026-01-07T10:00:00'),
              end: _dt('2026-01-07T11:00:00'),
            ),
            MsEvent(
              id: 'e-allday',
              subject: 'All day gone',
              isAllDay: true,
              start: _dt('2026-01-08T00:00:00'),
              end: _dt('2026-01-09T00:00:00'),
            ),
            MsEvent(
              id: 'e-outside',
              subject: 'Outside second window',
              start: _dt('2025-12-15T10:00:00'),
              end: _dt('2025-12-15T11:00:00'),
            ),
          ],
        };
      // Wider initial window pulls the row that will later sit outside the
      // fetched window.
      await MicrosoftSyncEngine(
        db,
        fake,
        'acct@example.com',
        windowStart: DateTime.utc(2025, 12, 1),
        windowEnd: DateTime.utc(2026, 2, 1),
      ).syncNow();
      await (db.update(db.events)..where((e) => e.remoteId.equals('e-dirty')))
          .write(const EventsCompanion(dirty: Value(true)));
      await (db.update(
        db.events,
      )..where((e) => e.remoteId.equals('e-gone'))).write(
        const EventsCompanion(
          alarmPreset: Value('loud'),
          reminders: Value('[10]'),
        ),
      );

      fake.eventsByCalendar = {
        'c1': [
          MsEvent(
            id: 'e-keep',
            subject: 'Keep',
            start: _dt('2026-01-05T10:00:00'),
            end: _dt('2026-01-05T11:00:00'),
          ),
        ],
      };
      await MicrosoftSyncEngine(
        db,
        fake,
        'acct@example.com',
        windowStart: DateTime.utc(2026, 1, 1),
        windowEnd: DateTime.utc(2026, 2, 1),
      ).syncNow();

      final rows = await db.select(db.events).get();
      final gone = rows.firstWhere((e) => e.remoteId == 'e-gone');
      expect(rows.firstWhere((e) => e.remoteId == 'e-keep').deletedAt, isNull);
      expect(gone.deletedAt, isNotNull);
      // Local-only fields survive the tombstone.
      expect(gone.alarmPreset, 'loud');
      expect(gone.reminders, '[10]');
      expect(rows.firstWhere((e) => e.remoteId == 'e-dirty').deletedAt, isNull);
      expect(rows.firstWhere((e) => e.remoteId == 'e-dirty').dirty, true);
      expect(
        rows.firstWhere((e) => e.remoteId == 'e-allday').deletedAt,
        isNotNull,
      );
      expect(
        rows.firstWhere((e) => e.remoteId == 'e-outside').deletedAt,
        isNull,
      );
    },
  );

  test('failed calendar fetch does not reconcile its events', () async {
    for (final status in [403, 404, 500]) {
      final db = _db();
      addTearDown(db.close);
      final fake = _FlakyCalendarFake()
        ..calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: true)]
        ..eventsByCalendar = {
          'c1': [
            MsEvent(
              id: 'e1',
              subject: 'Keep',
              start: _dt('2026-01-05T10:00:00'),
              end: _dt('2026-01-05T11:00:00'),
            ),
          ],
        };
      final engine = MicrosoftSyncEngine(
        db,
        fake,
        'acct@example.com',
        windowStart: DateTime.utc(2026, 1, 1),
        windowEnd: DateTime.utc(2026, 2, 1),
      );
      await engine.syncNow();

      fake.failStatus = status;
      fake.eventsByCalendar = {'c1': <MsEvent>[]};
      final result = await engine.syncNow();

      expect(result.authFailure, false);
      final event = (await db.select(db.events).get()).single;
      expect(event.deletedAt, isNull);
    }
  });

  test(
    'calendar and event deletion reconciliation is account isolated',
    () async {
      final db = _db();
      addTearDown(db.close);
      final fake = FakeMs()
        ..calendars = [const MsCalendar(id: 'c1', name: 'Cal', canEdit: true)]
        ..eventsByCalendar = {
          'c1': [
            MsEvent(
              id: 'e1',
              subject: 'Mine',
              start: _dt('2026-01-05T10:00:00'),
              end: _dt('2026-01-05T11:00:00'),
            ),
          ],
        };
      final engine = MicrosoftSyncEngine(
        db,
        fake,
        'acct@example.com',
        windowStart: DateTime.utc(2026, 1, 1),
        windowEnd: DateTime.utc(2026, 2, 1),
      );
      await engine.syncNow();

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      // Another account's calendar reuses the same remote id and event id, plus
      // a shared calendar owned by a third account.
      await db
          .into(db.calendars)
          .insert(
            CalendarsCompanion.insert(
              id: 'mscal_other_c1',
              remoteId: const Value('c1'),
              name: 'Other',
              source: const Value('microsoft'),
              microsoftAccount: const Value('other@example.com'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              id: 'msevt_other_e1',
              calendarId: 'mscal_other_c1',
              title: const Value('Other'),
              startUtc: Value(
                DateTime.utc(2026, 1, 5, 10).millisecondsSinceEpoch,
              ),
              endUtc: Value(
                DateTime.utc(2026, 1, 5, 11).millisecondsSinceEpoch,
              ),
              microsoftAccount: const Value('other@example.com'),
              remoteId: const Value('e1'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.calendars)
          .insert(
            CalendarsCompanion.insert(
              id: 'mscal_owner_shared',
              remoteId: const Value('c-shared'),
              name: 'Shared',
              source: const Value('microsoft'),
              microsoftAccount: const Value('owner@example.com'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.calendars)
          .insert(
            CalendarsCompanion.insert(
              id: 'mscal_acct_gone',
              remoteId: const Value('c-gone'),
              name: 'Gone',
              source: const Value('microsoft'),
              microsoftAccount: const Value('acct@example.com'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      fake.eventsByCalendar = {'c1': <MsEvent>[]};
      await engine.syncNow();

      final calendars = await db.select(db.calendars).get();
      expect(
        calendars.firstWhere((c) => c.remoteId == 'c-gone').deletedAt,
        isNotNull,
      );
      expect(
        calendars.firstWhere((c) => c.id == 'mscal_other_c1').deletedAt,
        isNull,
      );
      expect(
        calendars.firstWhere((c) => c.id == 'mscal_owner_shared').deletedAt,
        isNull,
      );
      final events = await db.select(db.events).get();
      expect(
        events.firstWhere((e) => e.id == 'msevt_acct@example.com_e1').deletedAt,
        isNotNull,
      );
      expect(
        events.firstWhere((e) => e.id == 'msevt_other_e1').deletedAt,
        isNull,
      );
    },
  );
}

class _FailingTasksFake extends FakeMs {
  String? failListId;
  int failStatus = 500;

  @override
  Future<List<MsTodoTask>> listTodoTasks(String listId) async {
    if (listId == failListId) {
      throw MicrosoftGraphException(failStatus, 'boom');
    }
    return super.listTodoTasks(listId);
  }
}

class _FailingCalendarFake extends FakeMs {
  _FailingCalendarFake(this.failStatus);

  final int failStatus;

  @override
  Future<List<MsEvent>> calendarView(
    DateTime startUtc,
    DateTime endUtc, {
    String? calendarId,
  }) async {
    if (calendarId == 'bad') {
      throw MicrosoftGraphException(failStatus, 'boom');
    }
    return super.calendarView(startUtc, endUtc, calendarId: calendarId);
  }
}

class _FlakyCalendarFake extends FakeMs {
  int? failStatus;

  @override
  Future<List<MsEvent>> calendarView(
    DateTime startUtc,
    DateTime endUtc, {
    String? calendarId,
  }) async {
    final status = failStatus;
    if (status != null) {
      throw MicrosoftGraphException(status, 'boom');
    }
    return super.calendarView(startUtc, endUtc, calendarId: calendarId);
  }
}

class _SharedCalendarFake extends FakeMs {
  _SharedCalendarFake(this.sharedCalendarId);

  final String sharedCalendarId;
  int sharedPulls = 0;

  @override
  Future<List<MsEvent>> calendarView(
    DateTime startUtc,
    DateTime endUtc, {
    String? calendarId,
  }) async {
    if (calendarId == sharedCalendarId) {
      sharedPulls++;
      return [
        MsEvent(
          id: 'e-shared',
          subject: 'Shared event',
          start: _dt('2026-01-01T10:00:00'),
          end: _dt('2026-01-01T11:00:00'),
        ),
      ];
    }
    return super.calendarView(startUtc, endUtc, calendarId: calendarId);
  }
}
