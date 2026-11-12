import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/event_repository.dart';
import 'package:ephemeron/data/repositories/note_repository.dart';
import 'package:ephemeron/data/repositories/occurrence_repository.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<String> _eventRow(
  AppDatabase db, {
  String id = 'ev1',
  String? notes,
  String? notesOverflowNoteId,
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
        mode: InsertMode.insertOrIgnore,
      );
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: id,
          calendarId: 'cal1',
          notes: Value(notes),
          notesOverflowNoteId: Value(notesOverflowNoteId),
          createdAt: now,
          updatedAt: now,
        ),
      );
  return id;
}

Future<Event> _event(AppDatabase db, String id) {
  return (db.select(db.events)..where((e) => e.id.equals(id))).getSingle();
}

void main() {
  test('nested folders, move, delete reparents to parent', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    final root = await repo.createFolder('Root');
    final child = await repo.createFolder('Child', parentId: root);
    final n = await repo.createNote(title: 'N', folderId: child);
    await repo.moveFolder(child, null);
    expect((await repo.breadcrumbs(child)).map((f) => f.name), ['Child']);
    final root2 = await repo.createFolder('Root2');
    await repo.moveFolder(child, root2);
    expect((await repo.breadcrumbs(child)).map((f) => f.name), [
      'Root2',
      'Child',
    ]);
    await repo.deleteFolder(root2);
    // Child reparented to root2's parent (null); note follows folder.
    expect((await repo.breadcrumbs(child)).map((f) => f.name), ['Child']);
    final notes = await repo.notesInFolder(child);
    expect(notes.map((e) => e.id), contains(n));
  });

  test('pin, duplicate, trash and restore', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    final id = await repo.createNote(title: 'A', body: 'hello');
    await repo.setPinned(id, true);
    final dup = await repo.duplicateNote(id);
    expect(dup, isNot(id));
    await repo.trashNote(id);
    expect(await repo.notesInFolder(null), hasLength(1));
    expect((await repo.notesInFolder(null)).single.id, dup);
    await repo.restoreNote(id);
    expect(await repo.notesInFolder(null), hasLength(2));
  });

  test('fts search finds snippet', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    await repo.createNote(title: 'Shopping', body: 'buy oat milk and honey');
    await repo.createNote(title: 'Other', body: 'unrelated text here');
    final hits = await repo.searchNotes('oat milk');
    expect(hits.length, 1);
    expect(hits.single.note.title, 'Shopping');
    expect(hits.single.snippet.toLowerCase(), contains('oat'));
  });

  test('overflow note for long event descriptions', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    final long = 'x' * 9000;
    final noteId = await repo.ensureOverflowNote('event1', long);
    expect(noteId, isNotNull);
    final note = await repo.getNote(noteId!);
    expect(note!.body!.length, greaterThan(8000));
    expect(note.linkedEventId, 'event1');
    // Idempotent: same note reused.
    expect(await repo.ensureOverflowNote('event1', long), noteId);
  });

  test(
    'ensureDescriptionNote creates, updates, and clears the same note',
    () async {
      final db = _db();
      addTearDown(db.close);
      final repo = NoteRepository(db, attachmentDir: null);
      await _eventRow(db);
      final noteId = await repo.ensureDescriptionNote('ev1', 'hello');
      expect(noteId, isNotNull);
      var note = await repo.getNote(noteId!);
      expect(note!.title, 'Event description');
      expect(note.body, 'hello');
      expect(note.linkedEventId, 'ev1');
      var event = await _event(db, 'ev1');
      expect(event.notesOverflowNoteId, noteId);

      // Idempotent for an unchanged body.
      expect(await repo.ensureDescriptionNote('ev1', 'hello'), noteId);
      await repo.ensureDescriptionNote('ev1', 'updated');
      note = await repo.getNote(noteId);
      expect(note!.body, 'updated');
      event = await _event(db, 'ev1');
      expect(event.notesOverflowNoteId, noteId);

      // Empty text clears the body but keeps the note and link.
      await repo.ensureDescriptionNote('ev1', '');
      note = await repo.getNote(noteId);
      expect(note!.body, '');
      expect(note.deletedAt, isNull);
      event = await _event(db, 'ev1');
      expect(event.notesOverflowNoteId, noteId);

      // No note is created for an empty description on a fresh event.
      await _eventRow(db, id: 'ev2');
      expect(await repo.ensureDescriptionNote('ev2', ''), isNull);
      event = await _event(db, 'ev2');
      expect(event.notesOverflowNoteId, isNull);
    },
  );

  test(
    'canonical description note updates event notes and enqueues sync',
    () async {
      final db = _db();
      addTearDown(db.close);
      final repo = NoteRepository(db, attachmentDir: null);
      await _eventRow(db, notes: 'old');
      final noteId = (await repo.ensureDescriptionNote('ev1', 'short'))!;
      final long = 'y' * 9000;
      await repo.updateNote(noteId, body: () => long);

      final event = await _event(db, 'ev1');
      expect(event.notes, NoteRepository.cappedEventNotes(long));
      expect(event.notes!.length, lessThan(long.length));
      expect(event.dirty, isTrue);
      final note = await repo.getNote(noteId);
      expect(note!.body, long);

      final outbox = await db.select(db.outbox).get();
      expect(
        outbox.where(
          (o) => o.entity == 'event' && o.entityId == 'ev1' && o.op == 'update',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'trashing a note keeps the event; deleting an event keeps the note',
    () async {
      final db = _db();
      addTearDown(db.close);
      final repo = NoteRepository(db, attachmentDir: null);
      await _eventRow(db, notes: 'description');
      final noteId = (await repo.ensureDescriptionNote('ev1', 'description'))!;

      await repo.trashNote(noteId);
      var event = await _event(db, 'ev1');
      expect(event.deletedAt, isNull);
      expect(event.notes, 'description');
      expect(event.notesOverflowNoteId, noteId);
      var note = await repo.getNote(noteId);
      expect(note!.deletedAt, isNotNull);

      await repo.restoreNote(noteId);
      final events = EventRepository(db, OccurrenceRepository(db));
      await events.deleteEvent('ev1');
      event = await _event(db, 'ev1');
      expect(event.deletedAt, isNotNull);
      note = await repo.getNote(noteId);
      expect(note!.deletedAt, isNull);
      expect(note.linkedEventId, 'ev1');
    },
  );

  test('eventForNote resolves canonical and direct event links', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    await _eventRow(db);
    final canonical = (await repo.ensureDescriptionNote('ev1', 'desc'))!;
    expect((await repo.eventForNote(canonical))!.id, 'ev1');

    await _eventRow(db, id: 'ev2');
    final direct = await repo.createNote(title: 'Prep', linkedEventId: 'ev2');
    expect((await repo.eventForNote(direct))!.id, 'ev2');
    expect(await repo.eventForNote('missing'), isNull);
  });

  test('event-linked notes listed', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    await repo.createNote(title: 'Prep', linkedEventId: 'ev1');
    await repo.createNote(title: 'Plain');
    final linked = await repo.notesForEvent('ev1');
    expect(linked.map((n) => n.title), ['Prep']);
  });

  test('watchNotesForEvent emits a newly linked note', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    final iterator = StreamIterator(repo.watchNotesForEvent('ev1'));
    addTearDown(iterator.cancel);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isEmpty);

    await repo.createNote(title: 'Prep', linkedEventId: 'ev1');
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.map((n) => n.title), ['Prep']);
  });

  test('backlinks resolve [[Title]] and list incoming links', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    final a = await repo.createNote(title: 'Alpha');
    final b = await repo.createNote(
      title: 'Beta',
      body: 'see [[Alpha]] and [[Missing]]',
    );
    expect(await repo.backlinks(a), hasLength(1));
    expect((await repo.backlinks(a)).first.id, b);
    expect(await repo.forwardLinks(b), hasLength(1));
    // Missing titles are ignored, not stored.
    expect(await repo.backlinks(b), isEmpty);
    // Renaming away drops the link.
    await repo.updateNote(b, body: () => 'no links');
    expect(await repo.backlinks(a), isEmpty);
  });

  test('md import uses file name as title', () async {
    final db = _db();
    addTearDown(db.close);
    final repo = NoteRepository(db, attachmentDir: null);
    final dir = await Directory.systemTemp.createTemp('ephemeron-test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/ideas.md');
    await file.writeAsString('# Hello\nbody text');
    final id = await repo.importMarkdownFile(file.path);
    final note = await repo.getNote(id);
    expect(note!.title, 'ideas');
    expect(note.body, contains('Hello'));
  });

  test('notes ordered pinned first then updatedAt desc', () async {
    final db = _db();
    addTearDown(db.close);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'a',
            title: const Value('a'),
            createdAt: now - 2000,
            updatedAt: now - 2000,
          ),
        );
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'b',
            title: const Value('b'),
            pinned: const Value(true),
            createdAt: now - 1000,
            updatedAt: now - 1000,
          ),
        );
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'c',
            title: const Value('c'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final repo = NoteRepository(db, attachmentDir: null);
    final notes = await repo.notesInFolder(null);
    expect(notes.map((n) => n.id).toList(), ['b', 'c', 'a']);
  });
}
