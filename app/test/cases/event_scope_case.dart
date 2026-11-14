import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/note_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/domain/sources/source_move.dart';
import 'package:ephemeron/features/calendar/presentation/event_editor_sheet.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<String> _setup(
  AppDatabase db, {
  String rrule = 'FREQ=DAILY;COUNT=5',
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: 'cal1',
          name: 'c',
          createdAt: now,
          updatedAt: now,
        ),
      );
  final repo = EventRepository(db, OccurrenceRepository(db));
  return repo.createEvent(
    calendarId: 'cal1',
    title: 'Standup',
    startUtc: DateTime.utc(2026, 3, 2, 9),
    endUtc: DateTime.utc(2026, 3, 2, 9, 30),
    tzId: 'UTC',
    rrule: rrule,
  );
}

Future<int> _count(AppDatabase db) async {
  return (await db.select(db.events).get()).length;
}

Future<String> _makeCalendar(
  AppDatabase db, {
  required String id,
  bool readOnly = false,
  String source = 'device',
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.calendars)
      .insert(
        CalendarsCompanion.insert(
          id: id,
          name: id,
          source: Value(source),
          readOnly: Value(readOnly),
          createdAt: now,
          updatedAt: now,
        ),
      );
  return id;
}

Future<String> _makeEvent(
  AppDatabase db, {
  required String id,
  required String calendarId,
  String? rrule,
  String? recurringMasterId,
  int? originalStart,
}) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: id,
          calendarId: calendarId,
          title: const Value('Event'),
          startUtc: Value(now),
          endUtc: Value(now + 3600000),
          rrule: Value(rrule),
          recurringMasterId: Value(recurringMasterId),
          originalStart: Value(originalStart),
          createdAt: now,
          updatedAt: now,
        ),
      );
  return id;
}

Future<void> _openEventEditor(
  WidgetTester tester,
  AppDatabase db,
  SharedPreferences prefs,
  Event event,
) async {
  const systemChannel = MethodChannel('ephemeron/system');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    systemChannel,
    (call) async => call.method == 'canPostNotifications' ? true : null,
  );
  addTearDown(() => messenger.setMockMethodCallHandler(systemChannel, null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith(
          (ref) async => SettingsRepository(prefs),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showEventEditor(context, event: event),
                child: const Text('Open event'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open event'));
  await tester.pumpAndSettle();
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(Container());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _saveEvent(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pump();
  await _pumpUntil(
    tester,
    find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data == 'Which events?' || w.data == 'Scheduling conflict'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('delete single creates cancelled exception', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.deleteOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
    );
    final rows = await db.select(db.events).get();
    expect(rows.length, 2);
    final ex = rows.firstWhere((e) => e.id != master);
    expect(ex.status, 'cancelled');
    expect(
      ex.originalStart,
      DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch,
    );
  });

  test('delete following truncates with UNTIL', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.deleteOccurrence(
      master,
      DateTime.utc(2026, 3, 4, 9),
      scope: EditScope.following,
    );
    final m = await (db.select(
      db.events,
    )..where((e) => e.id.equals(master))).getSingle();
    expect(m.rrule, contains('UNTIL=20260304T085959Z'));
    expect(m.rrule, isNot(contains('COUNT')));
  });

  test('delete following on first occurrence deletes all', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.deleteOccurrence(
      master,
      DateTime.utc(2026, 3, 2, 9),
      scope: EditScope.following,
    );
    final rows = await db.select(db.events).get();
    expect(rows.every((e) => e.deletedAt != null), isTrue);
  });

  test('delete all soft-deletes master and exceptions', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.deleteOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
    );
    expect(await _count(db), 2);
    await repo.deleteEvent(master);
    final rows = await db.select(db.events).get();
    expect(rows.every((e) => e.deletedAt != null), isTrue);
  });

  test('edit single creates exception with changed fields', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      title: 'Special standup',
    );
    final rows = await db.select(db.events).get();
    expect(rows.length, 2);
    final ex = rows.firstWhere((e) => e.id != master);
    expect(ex.title, 'Special standup');
    expect(ex.recurringMasterId, master);
  });

  test('edit following splits series', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 4, 9),
      scope: EditScope.following,
      title: 'New title',
      startUtc: DateTime.utc(2026, 3, 4, 10),
      endUtc: DateTime.utc(2026, 3, 4, 10, 30),
    );
    final rows = (await db.select(db.events).get()).where(
      (e) => e.deletedAt == null,
    );
    // Old master truncated + new master from Mar 4.
    expect(rows.length, 2);
    final split = rows.firstWhere((e) => e.id != master);
    expect(split.title, 'New title');
    expect(split.rrule, isNotNull);
    expect(
      DateTime.fromMillisecondsSinceEpoch(split.startUtc!, isUtc: true),
      DateTime.utc(2026, 3, 4, 10),
    );
  });

  test('edit all patches master', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.all,
      title: 'Renamed',
    );
    final m = await (db.select(
      db.events,
    )..where((e) => e.id.equals(master))).getSingle();
    expect(m.title, 'Renamed');
    expect(await _count(db), 1);
  });

  test('edit follows split series keeps notes on the new master', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 4, 9),
      scope: EditScope.following,
      notes: () => 'Later agenda',
    );
    final rows = (await db.select(db.events).get()).where(
      (e) => e.deletedAt == null,
    );
    final split = rows.firstWhere((e) => e.id != master);
    expect(split.notes, 'Later agenda');
  });

  test('edit single saves notes on the exception and can clear them', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      notes: () => 'Bring slides',
    );
    var rows = await db.select(db.events).get();
    var ex = rows.firstWhere((e) => e.id != master);
    expect(ex.notes, 'Bring slides');
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      notes: () => null,
    );
    rows = await db.select(db.events).get();
    ex = rows.firstWhere((e) => e.id != master);
    expect(ex.notes, isNull);
  });

  test('edit all saves and clears master notes', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 2, 9),
      scope: EditScope.all,
      notes: () => 'Updated notes',
    );
    var m = await (db.select(
      db.events,
    )..where((e) => e.id.equals(master))).getSingle();
    expect(m.notes, 'Updated notes');
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 2, 9),
      scope: EditScope.all,
      notes: () => null,
    );
    m = await (db.select(
      db.events,
    )..where((e) => e.id.equals(master))).getSingle();
    expect(m.notes, isNull);
  });

  test(
    'all-day create stores exclusive end date and edit updates range',
    () async {
      final db = _db();
      addTearDown(db.close);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db
          .into(db.calendars)
          .insert(
            CalendarsCompanion.insert(
              id: 'cal1',
              name: 'c',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final repo = EventRepository(db, OccurrenceRepository(db));
      final single = await repo.createEvent(
        calendarId: 'cal1',
        title: 'Holiday',
        allDay: true,
        startDate: '2026-04-10',
      );
      var row = await (db.select(
        db.events,
      )..where((e) => e.id.equals(single))).getSingle();
      expect(row.startDate, '2026-04-10');
      expect(row.endDate, '2026-04-11');

      final multi = await repo.createEvent(
        calendarId: 'cal1',
        title: 'Trip',
        allDay: true,
        startDate: '2026-05-01',
        endDate: '2026-05-04',
      );
      row = await (db.select(
        db.events,
      )..where((e) => e.id.equals(multi))).getSingle();
      expect(row.endDate, '2026-05-04');

      await repo.editOccurrence(
        multi,
        DateTime.utc(2026, 5, 1),
        scope: EditScope.all,
        startDate: '2026-05-02',
        endDate: '2026-05-06',
      );
      row = await (db.select(
        db.events,
      )..where((e) => e.id.equals(multi))).getSingle();
      expect(row.startDate, '2026-05-02');
      expect(row.endDate, '2026-05-06');
    },
  );

  test('rsvp updates attendee and queues sync', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final cal = await repo.createCalendar('C');
    final e = await repo.createEvent(calendarId: cal, title: 'M');
    await repo.setAttendees(e, ['me@example.com']);
    final atts = await repo.attendeesOf(e);
    expect(atts, hasLength(1));
    await repo.setRsvp(atts.first.id, 'accepted');
    final updated = await repo.attendeesOf(e);
    expect(updated.first.rsvp, 'accepted');
    final outbox = await db.select(db.outbox).get();
    expect(outbox, isNotEmpty);
  });
  test('edit single persists notes on the exception', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      notes: () => 'single note',
    );
    final rows = await db.select(db.events).get();
    final ex = rows.firstWhere(
      (e) => e.recurringMasterId == master && e.originalStart != null,
    );
    expect(ex.notes, 'single note');
  });

  test('edit all persists notes on the master', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.all,
      notes: () => 'all note',
    );
    final row = await (db.select(
      db.events,
    )..where((e) => e.id.equals(master))).getSingle();
    expect(row.notes, 'all note');
  });

  test('edit following persists notes on the split master', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 4, 9),
      scope: EditScope.following,
      notes: () => 'following note',
    );
    final rows = await db.select(db.events).get();
    final split = rows.firstWhere(
      (e) =>
          e.id != master &&
          e.deletedAt == null &&
          e.rrule != null &&
          e.recurringMasterId == null,
    );
    expect(split.notes, 'following note');
  });

  test(
    'split keeps a valid description link and gives the split none',
    () async {
      final db = _db();
      addTearDown(db.close);
      final master = await _setup(db);
      final repo = EventRepository(db, OccurrenceRepository(db));
      final notesRepo = NoteRepository(db, attachmentDir: null);
      final noteId = (await notesRepo.ensureDescriptionNote(
        master,
        'original',
      ))!;

      await repo.editOccurrence(
        master,
        DateTime.utc(2026, 3, 4, 9),
        scope: EditScope.following,
        notes: () => 'later',
      );

      final rows = (await db.select(db.events).get()).where(
        (e) => e.deletedAt == null,
      );
      final split = rows.firstWhere((e) => e.id != master);
      final old = await repo.getEvent(master);
      expect(old!.notesOverflowNoteId, noteId);
      expect(split.notesOverflowNoteId, isNull);

      // Reverse sync from the old canonical note must not update the split.
      await notesRepo.updateNote(noteId, body: () => 'updated');
      expect((await repo.getEvent(master))!.notes, 'updated');
      expect((await repo.getEvent(split.id))!.notes, 'later');
    },
  );

  test('split clears a stale description link on the old master', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await (db.update(db.events)..where((e) => e.id.equals(master))).write(
      const EventsCompanion(notesOverflowNoteId: Value('missing-note')),
    );

    await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 4, 9),
      scope: EditScope.following,
      notes: () => 'later',
    );

    final rows = (await db.select(db.events).get()).where(
      (e) => e.deletedAt == null,
    );
    final split = rows.firstWhere((e) => e.id != master);
    final old = await repo.getEvent(master);
    expect(old!.notesOverflowNoteId, isNull);
    expect(split.notesOverflowNoteId, isNull);
  });

  test(
    'resolveEventForOccurrence finds exception by original start or start',
    () async {
      final db = _db();
      addTearDown(db.close);
      final master = await _setup(db);
      final repo = EventRepository(db, OccurrenceRepository(db));
      await repo.editOccurrence(
        master,
        DateTime.utc(2026, 3, 3, 9),
        scope: EditScope.single,
        title: 'Special',
        startUtc: DateTime.utc(2026, 3, 3, 10),
        endUtc: DateTime.utc(2026, 3, 3, 10, 30),
      );
      final rows = await db.select(db.events).get();
      final ex = rows.firstWhere((e) => e.recurringMasterId == master);

      final byOriginal = await repo.resolveEventForOccurrence(
        master,
        occurrenceStartMs: DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch,
      );
      expect(byOriginal!.id, ex.id);
      expect(byOriginal.title, 'Special');
      final byStart = await repo.resolveEventForOccurrence(
        master,
        occurrenceStartMs: DateTime.utc(2026, 3, 3, 10).millisecondsSinceEpoch,
      );
      expect(byStart!.id, ex.id);
      final noMatch = await repo.resolveEventForOccurrence(
        master,
        occurrenceStartMs: DateTime.utc(2026, 3, 4, 9).millisecondsSinceEpoch,
      );
      expect(noMatch!.id, master);
      final noOccurrence = await repo.resolveEventForOccurrence(master);
      expect(noOccurrence!.id, master);

      // Cancelled exceptions are not selected.
      await repo.deleteOccurrence(
        master,
        DateTime.utc(2026, 3, 5, 9),
        scope: EditScope.single,
      );
      final cancelled = await repo.resolveEventForOccurrence(
        master,
        occurrenceStartMs: DateTime.utc(2026, 3, 5, 9).millisecondsSinceEpoch,
      );
      expect(cancelled!.id, master);
    },
  );

  test('description note syncs for a single-occurrence exception id', () async {
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final notesRepo = NoteRepository(db, attachmentDir: null);
    final long = 'z' * 9000;
    final affectedId = await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      notes: () => NoteRepository.cappedEventNotes(long),
    );
    expect(affectedId, isNot(master));
    final noteId = await notesRepo.ensureDescriptionNote(affectedId, long);
    expect(noteId, isNotNull);
    final note = await notesRepo.getNote(noteId!);
    expect(note!.body, long);
    expect(note.linkedEventId, affectedId);
    final ex = await repo.getEvent(affectedId);
    expect(ex!.notesOverflowNoteId, noteId);
    expect(ex.notes!.length, lessThan(long.length));
  });

  testWidgets('exception edit does not conflict with itself', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final exId = await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      title: 'Special',
    );
    final ex = await repo.getEvent(exId);
    await _openEventEditor(tester, db, prefs, ex!);

    await _saveEvent(tester);

    expect(find.text('Scheduling conflict'), findsNothing);
    expect(find.text('Which events?'), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('exception edit still detects a genuine overlap', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final exId = await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      title: 'Special',
    );
    await repo.createEvent(
      calendarId: 'cal1',
      title: 'Overlap',
      startUtc: DateTime.utc(2026, 3, 3, 9, 15),
      endUtc: DateTime.utc(2026, 3, 3, 9, 45),
      tzId: 'UTC',
    );
    final ex = await repo.getEvent(exId);
    await _openEventEditor(tester, db, prefs, ex!);

    await _saveEvent(tester);

    expect(find.text('Scheduling conflict'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await _disposeTree(tester);
  });

  testWidgets('single exception edit does not change series attendees', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final master = await _setup(db);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await repo.setAttendees(master, ['master@example.com']);
    final exId = await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 3, 9),
      scope: EditScope.single,
      title: 'Special',
    );
    final ex = await repo.getEvent(exId);
    await _openEventEditor(tester, db, prefs, ex!);
    final invitees = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.labelText?.startsWith('Invitees') ?? false),
    );
    expect(invitees, findsOneWidget);
    await tester.ensureVisible(invitees);
    await tester.enterText(invitees, 'exception@example.com');

    await _saveEvent(tester);
    expect(find.text('Which events?'), findsOneWidget);
    await tester.tap(find.text('This event'));
    await tester.pumpAndSettle();

    expect((await repo.attendeesOf(master)).map((a) => a.email), [
      'master@example.com',
    ]);
    expect(await repo.attendeesOf(exId), isEmpty);
    await _disposeTree(tester);
  });

  testWidgets('description save enqueues one event update', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final notesRepo = NoteRepository(db, attachmentDir: null);
    final calendarId = await repo.createCalendar('C');
    final id = await repo.createEvent(
      calendarId: calendarId,
      title: 'Description',
      startUtc: DateTime.utc(2026, 3, 3, 9),
      endUtc: DateTime.utc(2026, 3, 3, 9, 30),
      tzId: 'UTC',
      notes: 'old',
    );
    await notesRepo.ensureDescriptionNote(id, 'old');
    await db.delete(db.outbox).go();

    final event = await repo.getEvent(id);
    await _openEventEditor(tester, db, prefs, event!);
    final notesField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Notes',
    );
    expect(notesField, findsOneWidget);
    await tester.ensureVisible(notesField);
    await tester.enterText(notesField, 'new description');
    await _saveEvent(tester);

    final updates =
        await (db.select(db.outbox)..where(
              (o) =>
                  o.entity.equals('event') &
                  o.entityId.equals(id) &
                  o.op.equals('update'),
            ))
            .get();
    expect(updates, hasLength(1));
    final saved = await repo.getEvent(id);
    expect(saved!.notes, 'new description');
    expect(
      (await notesRepo.getNote(saved.notesOverflowNoteId!))!.body,
      'new description',
    );
    await _disposeTree(tester);
  });

  test(
    'moved single occurrence inherits master location, Meet and alerts',
    () async {
      final db = _db();
      addTearDown(db.close);
      final repo = EventRepository(db, OccurrenceRepository(db));
      final cal = await repo.createCalendar('Work');
      final master = await repo.createEvent(
        calendarId: cal,
        title: 'Series',
        startUtc: DateTime.utc(2026, 3, 2, 9),
        endUtc: DateTime.utc(2026, 3, 2, 10),
        tzId: 'UTC',
        rrule: 'FREQ=DAILY;COUNT=5',
        location: 'Room 1',
        colorId: '5',
        createMeet: true,
        reminders: '[30]',
        alarmPreset: 'full_short',
      );
      await (db.update(db.events)..where((e) => e.id.equals(master))).write(
        const EventsCompanion(
          meetUrl: Value('https://meet.google.com/abc-defg-hij'),
          visibility: Value('public'),
          transparency: Value('opaque'),
          endTzId: Value('America/New_York'),
        ),
      );

      final exId = await repo.editOccurrence(
        master,
        DateTime.utc(2026, 3, 3, 9),
        scope: EditScope.single,
        title: 'Moved',
        startUtc: DateTime.utc(2026, 3, 3, 11),
        endUtc: DateTime.utc(2026, 3, 3, 11, 30),
      );
      final ex = await repo.getEvent(exId);
      expect(ex!.location, 'Room 1');
      expect(ex.meetUrl, 'https://meet.google.com/abc-defg-hij');
      expect(ex.visibility, 'public');
      expect(ex.transparency, 'opaque');
      expect(ex.reminders, '[30]');
      expect(ex.alarmPreset, 'full_short');
      expect(ex.colorId, '5');
      expect(ex.createMeet, isTrue);
      expect(ex.endTzId, 'America/New_York');

      final overrideId = await repo.editOccurrence(
        master,
        DateTime.utc(2026, 3, 4, 9),
        scope: EditScope.single,
        location: 'Room 2',
        meetUrl: 'https://meet.google.com/zzz-yyyy-xxx',
        reminders: () => '[5]',
        alarmPreset: () => 'notification',
      );
      final override = await repo.getEvent(overrideId);
      expect(override!.location, 'Room 2');
      expect(override.meetUrl, 'https://meet.google.com/zzz-yyyy-xxx');
      expect(override.reminders, '[5]');
      expect(override.alarmPreset, 'notification');
    },
  );

  test('following split carries master fields', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final cal = await repo.createCalendar('Work');
    final master = await repo.createEvent(
      calendarId: cal,
      title: 'Series',
      startUtc: DateTime.utc(2026, 3, 2, 9),
      endUtc: DateTime.utc(2026, 3, 2, 10),
      tzId: 'UTC',
      rrule: 'FREQ=DAILY;COUNT=5',
      location: 'Room 1',
      colorId: '5',
      createMeet: true,
      reminders: '[30]',
      alarmPreset: 'full_short',
    );
    await (db.update(db.events)..where((e) => e.id.equals(master))).write(
      const EventsCompanion(
        meetUrl: Value('https://meet.google.com/abc-defg-hij'),
        visibility: Value('public'),
        transparency: Value('opaque'),
        endTzId: Value('America/New_York'),
      ),
    );

    final splitId = await repo.editOccurrence(
      master,
      DateTime.utc(2026, 3, 4, 9),
      scope: EditScope.following,
      title: 'Later series',
    );
    final split = await repo.getEvent(splitId);
    expect(split!.location, 'Room 1');
    expect(split.meetUrl, 'https://meet.google.com/abc-defg-hij');
    expect(split.visibility, 'public');
    expect(split.transparency, 'opaque');
    expect(split.colorId, '5');
    expect(split.createMeet, isTrue);
    expect(split.reminders, '[30]');
    expect(split.alarmPreset, 'full_short');
    expect(split.tzId, 'UTC');
    expect(split.endTzId, 'America/New_York');
  });

  testWidgets('event editor blocks saves to read-only calendars', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await _makeCalendar(db, id: 'ro', readOnly: true, source: 'google');
    final id = await _makeEvent(db, id: 'e1', calendarId: 'ro');
    final event = await repo.getEvent(id);
    await _openEventEditor(tester, db, prefs, event!);

    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('This calendar is read-only.'), findsOneWidget);
    expect((await repo.getEvent(id))!.title, 'Event');
    await _disposeTree(tester);
  });

  testWidgets('new-event save shows read-only error instead of throwing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    await _makeCalendar(db, id: 'ro', readOnly: true, source: 'google');
    const systemChannel = MethodChannel('ephemeron/system');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      systemChannel,
      (call) async => call.method == 'canPostNotifications' ? true : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(systemChannel, null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsRepositoryProvider.overrideWith(
            (ref) async => SettingsRepository(prefs),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showEventEditor(
                    context,
                    restoredDraft: {
                      'title': 'Blocked',
                      'calendarId': 'ro',
                      'startMs': DateTime(2026, 3, 2, 9).millisecondsSinceEpoch,
                      'endMs': DateTime(2026, 3, 2, 10).millisecondsSinceEpoch,
                    },
                  ),
                  child: const Text('Open event'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open event'));
    await tester.pumpAndSettle();

    final create = find.widgetWithText(FilledButton, 'Create');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('That calendar is read-only.'), findsOneWidget);
    expect(await db.select(db.events).get(), isEmpty);
    await _disposeTree(tester);
  });

  test('createEvent rejects read-only Google and local calendars', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    for (final (id, source) in [
      ('ro-google', 'google'),
      ('ro-local', 'device'),
    ]) {
      await _makeCalendar(db, id: id, readOnly: true, source: source);
      await expectLater(
        repo.createEvent(calendarId: id, title: 'Blocked'),
        throwsA(isA<SourceMoveException>()),
      );
    }
  });

  test('moveEventToCalendar rejects read-only source and target', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await _makeCalendar(db, id: 'ro', readOnly: true, source: 'google');
    await _makeCalendar(db, id: 'writable');
    await _makeEvent(db, id: 'from-ro', calendarId: 'ro');
    await _makeEvent(db, id: 'from-w', calendarId: 'writable');

    await expectLater(
      repo.moveEventToCalendar('from-ro', 'writable'),
      throwsA(isA<SourceMoveException>()),
    );
    await expectLater(
      repo.moveEventToCalendar('from-w', 'ro'),
      throwsA(isA<SourceMoveException>()),
    );
  });

  test(
    'edit/delete occurrence and delete event reject read-only source',
    () async {
      final db = _db();
      addTearDown(db.close);
      final repo = EventRepository(db, OccurrenceRepository(db));
      await _makeCalendar(db, id: 'ro', readOnly: true, source: 'google');
      final master = await _makeEvent(
        db,
        id: 'master',
        calendarId: 'ro',
        rrule: 'FREQ=DAILY;COUNT=5',
      );
      final cut = DateTime.utc(2026, 3, 3, 9);

      await expectLater(
        repo.editOccurrence(master, cut, scope: EditScope.single, title: 'No'),
        throwsA(isA<SourceMoveException>()),
      );
      await expectLater(
        repo.deleteOccurrence(master, cut, scope: EditScope.single),
        throwsA(isA<SourceMoveException>()),
      );
      await expectLater(
        repo.deleteEvent(master),
        throwsA(isA<SourceMoveException>()),
      );
      final rows = await db.select(db.events).get();
      expect(rows.single.deletedAt, isNull);
    },
  );

  test(
    'exception under a read-only master rejects edits and deletes',
    () async {
      final db = _db();
      addTearDown(db.close);
      final repo = EventRepository(db, OccurrenceRepository(db));
      await _makeCalendar(db, id: 'ro', readOnly: true, source: 'google');
      await _makeCalendar(db, id: 'writable');
      final master = await _makeEvent(
        db,
        id: 'master',
        calendarId: 'ro',
        rrule: 'FREQ=DAILY;COUNT=5',
      );
      final originalStart = DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch;
      final ex = await _makeEvent(
        db,
        id: 'exception',
        calendarId: 'writable',
        recurringMasterId: master,
        originalStart: originalStart,
      );

      await expectLater(
        repo.editOccurrence(
          master,
          DateTime.fromMillisecondsSinceEpoch(originalStart, isUtc: true),
          scope: EditScope.single,
          title: 'No',
        ),
        throwsA(isA<SourceMoveException>()),
      );
      await expectLater(
        repo.deleteEvent(ex),
        throwsA(isA<SourceMoveException>()),
      );
    },
  );

  test('read-only events reject attendee and RSVP updates', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    await _makeCalendar(db, id: 'ro', readOnly: true, source: 'google');
    final event = await _makeEvent(db, id: 'master', calendarId: 'ro');
    await db
        .into(db.eventAttendees)
        .insert(
          EventAttendeesCompanion.insert(
            id: 'att1',
            eventId: event,
            email: 'guest@example.com',
            isSelf: const Value(true),
          ),
        );

    await expectLater(
      repo.setAttendees(event, ['other@example.com']),
      throwsA(isA<SourceMoveException>()),
    );
    await expectLater(
      repo.setRsvp('att1', 'accepted'),
      throwsA(isA<SourceMoveException>()),
    );
    final attendees = await repo.attendeesOf(event);
    expect(attendees.single.email, 'guest@example.com');
    expect(attendees.single.rsvp, isNull);
    final outbox = await (db.select(
      db.outbox,
    )..where((o) => o.entityId.equals(event))).get();
    expect(outbox, isEmpty);
  });

  test('writable local calendars still create, edit, and delete', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final cal = await repo.createCalendar('Local');
    final id = await repo.createEvent(
      calendarId: cal,
      title: 'Local event',
      startUtc: DateTime.utc(2026, 3, 2, 9),
      endUtc: DateTime.utc(2026, 3, 2, 10),
      tzId: 'UTC',
    );
    await repo.editOccurrence(
      id,
      DateTime.utc(2026, 3, 2, 9),
      scope: EditScope.all,
      title: 'Renamed',
    );
    expect((await repo.getEvent(id))!.title, 'Renamed');
    await repo.deleteEvent(id);
    expect((await repo.getEvent(id))!.deletedAt, isNotNull);
  });
}
