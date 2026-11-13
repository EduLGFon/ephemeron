import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/countdown_repository.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/focus_repository.dart';
import 'package:ephemeron/data/repositories/habit_repository.dart';
import 'package:ephemeron/data/repositories/note_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/data/repositories/task_repository.dart';
import 'package:ephemeron/features/auth/application/auth_providers.dart';
import 'package:ephemeron/features/calendar/presentation/event_details_sheet.dart';
import 'package:ephemeron/features/notes/presentation/markdown_preview.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:ephemeron/features/sync/application/pending_operations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<String> _eventWithAttendees(
  AppDatabase db, {
  required List<({String email, String? rsvp, bool self, bool org})> rows,
  String? notes,
  String? meetUrl,
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
  final id = await repo.createEvent(
    calendarId: 'cal1',
    title: 'Invite',
    startUtc: DateTime.utc(2026, 3, 2, 9),
    endUtc: DateTime.utc(2026, 3, 2, 10),
    tzId: 'UTC',
    notes: notes,
  );
  if (meetUrl != null) {
    await (db.update(db.events)..where((e) => e.id.equals(id))).write(
      EventsCompanion(meetUrl: Value(meetUrl)),
    );
  }
  for (final r in rows) {
    await db
        .into(db.eventAttendees)
        .insert(
          EventAttendeesCompanion.insert(
            id: '${id}_${r.email}',
            eventId: id,
            email: r.email,
            rsvp: Value(r.rsvp),
            isSelf: Value(r.self),
            isOrganizer: Value(r.org),
          ),
        );
  }
  return id;
}

Future<void> _openEventSheet(
  WidgetTester tester,
  AppDatabase db,
  SharedPreferences prefs,
  String eventId, {
  int? occurrenceStartMs,
  PendingOperations? pendingOperations,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith(
          (ref) async => SettingsRepository(prefs),
        ),
        googleAccountProvider.overrideWith(_SignedInAccount.new),
        googleAccountsProvider.overrideWith(_Accounts.new),
        if (pendingOperations != null)
          pendingOperationsProvider.overrideWithValue(pendingOperations),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showEventDetails(
                  context,
                  eventId,
                  occurrenceStartMs: occurrenceStartMs,
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
}

void _collectSpans(InlineSpan span, List<TextSpan> out) {
  if (span is! TextSpan) return;
  if (span.text != null) out.add(span);
  for (final child in span.children ?? const <InlineSpan>[]) {
    _collectSpans(child, out);
  }
}

class _SignedInAccount extends GoogleAccountNotifier {
  @override
  String? build() => 'me@x.com';
}

class _Accounts extends GoogleAccountsNotifier {
  @override
  List<String> build() => const ['me@x.com'];
}

/// Records destructive event actions without arming the durable undo timer.
class _RecordingPendingOperations extends PendingOperations {
  // The repositories need the same db instance, so a super parameter cannot
  // be forwarded to the other constructor arguments.
  // ignore: use_super_parameters
  _RecordingPendingOperations(AppDatabase db)
    : super(
        db,
        tasks: TaskRepository(db),
        notes: NoteRepository(db),
        habits: HabitRepository(db),
        countdowns: CountdownRepository(db),
        focus: FocusRepository(db),
        events: EventRepository(db, OccurrenceRepository(db)),
      );

  final List<({String eventId, DateTime originalStart, EditScope scope})>
  occurrenceDeletes = [];
  final List<String> eventDeletes = [];
  final List<String> cancelled = [];

  @override
  Future<void> start() async {}

  @override
  Future<String> scheduleEventDelete(String id) async {
    eventDeletes.add(id);
    return 'delete:$id';
  }

  @override
  Future<String> scheduleEventDeleteOccurrence(
    String id,
    DateTime originalStartUtc, {
    required EditScope scope,
  }) async {
    occurrenceDeletes.add((
      eventId: id,
      originalStart: originalStartUtc,
      scope: scope,
    ));
    return 'occurrence:$id';
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
  }
}

void main() {
  test('flagged isSelf row wins over email match', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final id = await _eventWithAttendees(
      db,
      rows: [
        (email: 'me@x.com', rsvp: 'tentative', self: true, org: false),
        (email: 'other@x.com', rsvp: 'accepted', self: false, org: false),
      ],
    );
    final self = await repo.selfAttendeeOf(id, ['other@x.com']);
    expect(self?.email, 'me@x.com');
  });

  test('email match resolves self when flag missing', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final id = await _eventWithAttendees(
      db,
      rows: [
        (email: 'boss@x.com', rsvp: null, self: false, org: true),
        (email: 'me@x.com', rsvp: 'accepted', self: false, org: false),
      ],
    );
    final self = await repo.selfAttendeeOf(id, ['me@x.com']);
    expect(self?.email, 'me@x.com');
    expect(self?.rsvp, 'accepted');
  });

  test('known accounts without match resolve to null', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final id = await _eventWithAttendees(
      db,
      rows: [
        (email: 'stranger@x.com', rsvp: 'accepted', self: false, org: false),
      ],
    );
    expect(await repo.selfAttendeeOf(id, ['me@x.com']), isNull);
  });

  test('no attendees resolve to null', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final id = await _eventWithAttendees(db, rows: []);
    expect(await repo.selfAttendeeOf(id, ['me@x.com']), isNull);
    expect(await repo.selfAttendeeOf(id, []), isNull);
  });

  test('signed out falls back to first guest', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final id = await _eventWithAttendees(
      db,
      rows: [
        (email: 'boss@x.com', rsvp: null, self: false, org: true),
        (email: 'guest@x.com', rsvp: null, self: false, org: false),
      ],
    );
    final self = await repo.selfAttendeeOf(id, []);
    expect(self?.email, 'guest@x.com');
  });

  test('setRsvp heals missing isSelf flag', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final id = await _eventWithAttendees(
      db,
      rows: [(email: 'me@x.com', rsvp: null, self: false, org: false)],
    );
    final row = (await repo.attendeesOf(id)).single;
    await repo.setRsvp(row.id, 'accepted');
    final after = await repo.selfAttendeeOf(id, ['me@x.com']);
    expect(after?.rsvp, 'accepted');
    expect(after?.isSelf, isTrue);
  });

  testWidgets('RSVP chip updates immediately after selection', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final id = await _eventWithAttendees(
      db,
      rows: [(email: 'me@x.com', rsvp: null, self: true, org: false)],
    );
    await _openEventSheet(tester, db, prefs, id);
    expect(find.text('My response:'), findsOneWidget);
    final yes = find.widgetWithText(ChoiceChip, 'Yes');
    expect(tester.widget<ChoiceChip>(yes).selected, isFalse);

    await tester.ensureVisible(yes);
    await tester.tap(yes);
    await tester.pumpAndSettle();

    // The same sheet (no reopen) reflects the new response.
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Yes'))
          .selected,
      isTrue,
    );
    final row = (await EventRepository(
      db,
      OccurrenceRepository(db),
    ).attendeesOf(id)).single;
    expect(row.rsvp, 'accepted');
    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
  });

  testWidgets('event notes render markdown with tappable links', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final id = await _eventWithAttendees(
      db,
      rows: [(email: 'me@x.com', rsvp: 'accepted', self: true, org: false)],
      notes: 'Line one\nLine **two** [docs](https://example.com/docs)',
      meetUrl: 'https://meet.google.com/abc-defg-hij',
    );
    await _openEventSheet(tester, db, prefs, id);

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    final rich = tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(MarkdownBody),
        matching: find.byType(RichText),
      ),
    );
    expect(
      rich.map((r) => r.text.toPlainText()).join('\n'),
      'Line one\nLine two docs (https://example.com/docs)',
    );
    final spans = <TextSpan>[];
    for (final r in rich) {
      _collectSpans(r.text, spans);
    }
    // Both the anchor label and the appended URL are tappable.
    expect(spans.any((s) => s.text == 'docs' && s.recognizer != null), isTrue);
    expect(
      spans.any(
        (s) =>
            (s.text ?? '').contains('https://example.com/docs') &&
            s.recognizer != null,
      ),
      isTrue,
    );

    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
  });

  Future<String> seedSeries(AppDatabase db, String calendarId) async {
    final repo = EventRepository(db, OccurrenceRepository(db));
    return repo.createEvent(
      calendarId: calendarId,
      title: 'Series',
      startUtc: DateTime.utc(2026, 3, 2, 9),
      endUtc: DateTime.utc(2026, 3, 2, 9, 30),
      tzId: 'UTC',
      rrule: 'FREQ=DAILY;COUNT=5',
    );
  }

  void stubSystemChannel() {
    const systemChannel = MethodChannel('ephemeron/system');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      systemChannel,
      (call) async => call.method == 'canPostNotifications' ? true : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(systemChannel, null));
  }

  testWidgets('details edit on a later occurrence targets that occurrence', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    stubSystemChannel();
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final cal = await repo.createCalendar('Series calendar');
    final master = await seedSeries(db, cal);
    final later = DateTime.utc(2026, 3, 4, 9);
    await _openEventSheet(
      tester,
      db,
      prefs,
      master,
      occurrenceStartMs: later.millisecondsSinceEpoch,
    );

    final edit = find.text('Edit');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      if (find.text('Which events?').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Which events?'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('This event'));
    await tester.pump();
    await tester.tap(find.text('This event'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.events).get();
    final ex = rows.firstWhere((e) => e.recurringMasterId == master);
    expect(ex.originalStart, later.millisecondsSinceEpoch);
    expect(ex.startUtc, later.millisecondsSinceEpoch);
    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
  });

  testWidgets('details delete single on a later occurrence uses that start', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final cal = await repo.createCalendar('Series calendar');
    final master = await seedSeries(db, cal);
    final pending = _RecordingPendingOperations(db);
    final later = DateTime.utc(2026, 3, 4, 9);
    await _openEventSheet(
      tester,
      db,
      prefs,
      master,
      occurrenceStartMs: later.millisecondsSinceEpoch,
      pendingOperations: pending,
    );

    final delete = find.text('Delete');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('Which events?'), findsOneWidget);
    await tester.ensureVisible(find.text('This event'));
    await tester.pump();
    await tester.tap(find.text('This event'));
    await tester.pumpAndSettle();

    final op = pending.occurrenceDeletes.single;
    expect(op.eventId, master);
    expect(op.originalStart, later);
    expect(op.scope, EditScope.single);
    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
  });

  testWidgets('details delete cancels an overridden series occurrence', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final cal = await repo.createCalendar('Series calendar');
    final master = await seedSeries(db, cal);
    final original = DateTime.utc(2026, 3, 3, 9);
    final moved = DateTime.utc(2026, 3, 3, 11);
    final exId = await repo.editOccurrence(
      master,
      original,
      scope: EditScope.single,
      title: 'Moved',
      startUtc: moved,
      endUtc: DateTime.utc(2026, 3, 3, 11, 30),
    );
    final pending = _RecordingPendingOperations(db);
    await _openEventSheet(
      tester,
      db,
      prefs,
      master,
      occurrenceStartMs: moved.millisecondsSinceEpoch,
      pendingOperations: pending,
    );

    final delete = find.text('Delete');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();

    final op = pending.occurrenceDeletes.single;
    expect(op.eventId, master);
    expect(op.originalStart, original);
    expect(op.scope, EditScope.single);
    expect(pending.eventDeletes, isEmpty);

    // Apply the same operation directly; widget fake time does not advance
    // the real clock used by the durable undo timer.
    await repo.deleteOccurrence(master, original, scope: EditScope.single);
    final exception = await repo.getEvent(exId);
    expect(exception!.status, 'cancelled');
    expect((await repo.getEvent(master))!.deletedAt, isNull);
    final occurrences = OccurrenceRepository(db);
    await occurrences.rebuildWindow(
      windowStartUtc: DateTime.utc(2026, 3, 1),
      windowEndUtc: DateTime.utc(2026, 3, 8),
    );
    expect(await occurrences.occurrencesForDay('2026-03-03'), isEmpty);
    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
  });

  testWidgets('details delete refuses a source that became read-only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final repo = EventRepository(db, OccurrenceRepository(db));
    final cal = await repo.createCalendar('Writable');
    final id = await repo.createEvent(
      calendarId: cal,
      title: 'Event',
      startUtc: DateTime.utc(2026, 3, 3, 9),
      endUtc: DateTime.utc(2026, 3, 3, 10),
      tzId: 'UTC',
    );
    final pending = _RecordingPendingOperations(db);
    await _openEventSheet(tester, db, prefs, id, pendingOperations: pending);
    await (db.update(db.calendars)..where((c) => c.id.equals(cal))).write(
      const CalendarsCompanion(readOnly: Value(true)),
    );

    final delete = find.text('Delete');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(find.text('This calendar is read-only.'), findsOneWidget);
    expect(find.text('Event deleted'), findsNothing);
    expect(pending.occurrenceDeletes, isEmpty);
    expect(pending.eventDeletes, isEmpty);
    expect((await repo.getEvent(id))!.deletedAt, isNull);
    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
  });

  testWidgets('read-only details hide move, edit and delete', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.calendars)
        .insert(
          CalendarsCompanion.insert(
            id: 'ro',
            name: 'Shared',
            source: const Value('google'),
            readOnly: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final id = 'ro-event';
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: id,
            calendarId: 'ro',
            title: const Value('Shared event'),
            startUtc: Value(DateTime.utc(2026, 3, 3, 9).millisecondsSinceEpoch),
            endUtc: Value(DateTime.utc(2026, 3, 3, 10).millisecondsSinceEpoch),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _openEventSheet(tester, db, prefs, id);

    expect(find.byKey(const Key('read-only-calendar')), findsOneWidget);
    expect(find.text('Read-only calendar'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.byIcon(Icons.swap_horiz), findsNothing);
    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
  });
}
