import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:ephemeron/core/db/db_provider.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:ephemeron/features/auth/application/auth_providers.dart';
import 'package:ephemeron/features/calendar/presentation/event_details_sheet.dart';
import 'package:ephemeron/features/notes/presentation/markdown_preview.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
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
  String eventId,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWith(
          (ref) async => SettingsRepository(prefs),
        ),
        googleAccountProvider.overrideWith(_SignedInAccount.new),
        googleAccountsProvider.overrideWith(_Accounts.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showEventDetails(context, eventId),
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
}
