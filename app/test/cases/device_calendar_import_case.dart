// Device calendar import: idempotent upserts, recurring grouping, safe
// reconciliation, dirty-row preservation, and mapping persistence.
import 'package:device_calendar_plus/device_calendar_plus.dart' as device;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/services/device_calendar_import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _seedCalendar(AppDatabase db) async {
  const now = 1700000000000;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: 'cal1',
          name: 'Local',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<DeviceCalendarImportService> _service(AppDatabase db) async {
  final repo = EventRepository(db, OccurrenceRepository(db));
  return DeviceCalendarImportService(
    repo,
    preferences: await SharedPreferences.getInstance(),
  );
}

device.Event _event({
  required String eventId,
  required String instanceId,
  required String title,
  required DateTime start,
  Duration duration = const Duration(hours: 1),
  device.RecurrenceRule? rule,
}) {
  return device.Event(
    eventId: eventId,
    instanceId: instanceId,
    calendarId: 'device-cal',
    title: title,
    startDate: start,
    endDate: start.add(duration),
    isAllDay: false,
    availability: device.EventAvailability.busy,
    status: device.EventStatus.confirmed,
    timeZone: 'UTC',
    isRecurring: rule != null,
    recurrenceRule: rule,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('importing the same device event twice updates one row', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db);
    final service = await _service(db);
    final start = DateTime.utc(2026, 11, 12, 9);

    final first = await service.importEvents(
      targetCalendarId: 'cal1',
      events: [
        _event(
          eventId: 'evt1',
          instanceId: 'evt1',
          title: 'First',
          start: start,
        ),
      ],
    );
    expect(first.inserted, 1);

    // Local-only fields are user data: a refresh must not clear them.
    await (db.update(
      db.events,
    )..where((e) => e.remoteId.equals('device:evt1'))).write(
      const EventsCompanion(
        reminders: Value('["-PT15M"]'),
        visibility: Value('private'),
        colorId: Value('7'),
        createMeet: Value(true),
        alarmPreset: Value('gentle'),
      ),
    );

    final second = await service.importEvents(
      targetCalendarId: 'cal1',
      events: [
        _event(
          eventId: 'evt1',
          instanceId: 'evt1',
          title: 'Renamed',
          start: start,
        ),
      ],
    );
    expect(second.updated, 1);

    final rows = await db.select(db.events).get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.title, 'Renamed');
    expect(row.remoteId, 'device:evt1');
    expect(row.dirty, isFalse);
    expect(row.googleAccount, isNull);
    expect(row.microsoftAccount, isNull);
    expect(row.reminders, '["-PT15M"]');
    expect(row.visibility, 'private');
    expect(row.colorId, '7');
    expect(row.createMeet, isTrue);
    expect(row.alarmPreset, 'gentle');
    expect(await db.select(db.pendingOperations).get(), isEmpty);
  });

  test('recurring instances group into one master with one rrule', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db);
    final service = await _service(db);
    const rule = device.DailyRecurrence(end: device.CountEnd(5));
    final later = _event(
      eventId: 'rec1',
      instanceId: 'rec1-2',
      title: 'Standup',
      start: DateTime.utc(2026, 11, 13, 9),
      rule: rule,
    );
    final earliest = _event(
      eventId: 'rec1',
      instanceId: 'rec1-1',
      title: 'Standup',
      start: DateTime.utc(2026, 11, 12, 9),
      rule: rule,
    );

    final result = await service.importEvents(
      targetCalendarId: 'cal1',
      events: [later, earliest],
    );
    expect(result.inserted, 1);

    final rows = await db.select(db.events).get();
    expect(rows, hasLength(1));
    expect(
      rows.single.startUtc,
      DateTime.utc(2026, 11, 12, 9).millisecondsSinceEpoch,
    );
    expect(rows.single.rrule, rule.rruleString);
  });

  test('grouping falls back to instanceId and keeps the earliest start', () {
    final later = _event(
      eventId: '',
      instanceId: 'single',
      title: 'Later',
      start: DateTime.utc(2026, 11, 13, 9),
    );
    final earliest = _event(
      eventId: '',
      instanceId: 'single',
      title: 'Earliest',
      start: DateTime.utc(2026, 11, 12, 9),
    );
    final recurring = _event(
      eventId: 'series',
      instanceId: 'series-1',
      title: 'Series',
      start: DateTime.utc(2026, 11, 12, 10),
    );
    final noIds = _event(
      eventId: '',
      instanceId: '',
      title: 'Unkeyed',
      start: DateTime.utc(2026, 11, 12, 11),
    );

    final groups = groupDeviceEvents([later, earliest, recurring, noIds]);
    expect(groups, hasLength(2));
    final single = groups.firstWhere((g) => g.key == 'single');
    expect(single.event.title, 'Earliest');
    expect(groups.any((g) => g.key == 'series'), isTrue);
    expect(groups.any((g) => g.key.isEmpty), isFalse);
  });

  test('grouping keeps an rrule from a later occurrence', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db);
    final service = await _service(db);
    const rule = device.DailyRecurrence(end: device.CountEnd(5));
    final earliestWithoutRule = _event(
      eventId: 'rec2',
      instanceId: 'rec2-1',
      title: 'Standup',
      start: DateTime.utc(2026, 11, 12, 9),
    );
    final laterWithRule = _event(
      eventId: 'rec2',
      instanceId: 'rec2-2',
      title: 'Standup',
      start: DateTime.utc(2026, 11, 13, 9),
      rule: rule,
    );

    await service.importEvents(
      targetCalendarId: 'cal1',
      events: [earliestWithoutRule, laterWithRule],
    );

    final rows = await db.select(db.events).get();
    expect(rows, hasLength(1));
    expect(rows.single.rrule, rule.rruleString);
    expect(
      rows.single.startUtc,
      DateTime.utc(2026, 11, 13, 9).millisecondsSinceEpoch,
    );
  });

  test(
    'reconciliation only soft-deletes missing non-dirty device rows',
    () async {
      final db = _db();
      addTearDown(db.close);
      await _seedCalendar(db);
      final service = await _service(db);
      await service.importEvents(
        targetCalendarId: 'cal1',
        events: [
          _event(
            eventId: 'evt1',
            instanceId: 'evt1',
            title: 'Keep',
            start: DateTime.utc(2026, 11, 12, 9),
          ),
          _event(
            eventId: 'evt2',
            instanceId: 'evt2',
            title: 'Dirty missing',
            start: DateTime.utc(2026, 11, 12, 10),
          ),
          _event(
            eventId: 'evt3',
            instanceId: 'evt3',
            title: 'Missing',
            start: DateTime.utc(2026, 11, 12, 11),
          ),
        ],
      );
      final repo = EventRepository(db, OccurrenceRepository(db));
      const now = 1700000000000;
      await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              id: 'google-evt',
              calendarId: 'cal1',
              title: const Value('Google row'),
              remoteId: const Value('google:abc'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await (db.update(db.events)
            ..where((e) => e.remoteId.equals('device:evt2')))
          .write(const EventsCompanion(dirty: Value(true)));

      final deleted = await repo.reconcileImportedDeviceEvents(
        calendarId: 'cal1',
        retainedRemoteIds: {'device:evt1'},
        nowMs: now,
      );
      expect(deleted, 1);

      final rows = await db.select(db.events).get();
      final byRemote = {
        for (final row in rows.where((r) => r.remoteId != null))
          row.remoteId!: row,
      };
      expect(byRemote['device:evt1']!.deletedAt, isNull);
      expect(byRemote['device:evt2']!.deletedAt, isNull);
      expect(byRemote['device:evt3']!.deletedAt, now);
      expect(byRemote['google:abc']!.deletedAt, isNull);

      final again = await repo.reconcileImportedDeviceEvents(
        calendarId: 'cal1',
        retainedRemoteIds: {'device:evt1'},
        nowMs: now + 1,
      );
      expect(again, 0);
    },
  );

  test('a dirty imported row is not overwritten by a refresh', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db);
    final service = await _service(db);
    const rule = device.DailyRecurrence(end: device.CountEnd(3));
    final start = DateTime.utc(2026, 11, 12, 9);
    await service.importEvents(
      targetCalendarId: 'cal1',
      events: [
        _event(
          eventId: 'evt1',
          instanceId: 'evt1',
          title: 'Imported',
          start: start,
          rule: rule,
        ),
      ],
    );
    await (db.update(
      db.events,
    )..where((e) => e.remoteId.equals('device:evt1'))).write(
      const EventsCompanion(title: Value('Local edit'), dirty: Value(true)),
    );

    final result = await service.importEvents(
      targetCalendarId: 'cal1',
      events: [
        _event(
          eventId: 'evt1',
          instanceId: 'evt1',
          title: 'Device rename',
          start: start,
          rule: rule,
        ),
      ],
    );
    expect(result.skipped, 1);

    final row = await (db.select(
      db.events,
    )..where((e) => e.remoteId.equals('device:evt1'))).getSingle();
    expect(row.title, 'Local edit');
    expect(row.dirty, isTrue);
  });

  test('mapping persistence round-trips ids only', () async {
    final db = _db();
    addTearDown(db.close);
    await _seedCalendar(db);
    final prefs = await SharedPreferences.getInstance();
    final service = await _service(db);

    expect(await service.hasMappings(), isFalse);
    await service.saveMappings({'device-1': 'cal1', 'device-2': 'cal1'});
    expect(await service.hasMappings(), isTrue);
    expect(await service.loadMappings(), {
      'device-1': 'cal1',
      'device-2': 'cal1',
    });
    expect(prefs.getString('deviceImport.target.device-1'), 'cal1');

    final reopened = DeviceCalendarImportService(
      EventRepository(db, OccurrenceRepository(db)),
      preferences: prefs,
    );
    expect(await reopened.loadMappings(), {
      'device-1': 'cal1',
      'device-2': 'cal1',
    });

    await reopened.removeMappings({'device-1'});
    expect(await reopened.loadMappings(), {'device-2': 'cal1'});
  });
}
