part of '../note_repository.dart';

mixin _NoteCrudOps on _NoteRepositoryBase {
  Future<void> refreshLinks(String noteId);

  Future<String> createNote({
    required String title,
    String? body,
    String? folderId,
    String? linkedEventId,
  }) async {
    final id = newId();
    final now = nowMs();
    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            id: id,
            folderId: Value(folderId),
            title: Value(title),
            body: Value(body),
            linkedEventId: Value(linkedEventId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await refreshLinks(id);
    return id;
  }

  Future<Note?> getNote(String id) {
    return (_db.select(
      _db.notes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Note?> watchNote(String id) {
    return (_db.select(
      _db.notes,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<void> updateNote(
    String id, {
    String? title,
    String? Function()? body,
    String? Function()? folderId,
    bool syncEventNotes = true,
  }) async {
    final newBody = body?.call();
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        title: title == null ? const Value.absent() : Value(title),
        body: body == null ? const Value.absent() : Value(newBody),
        folderId: folderId == null ? const Value.absent() : Value(folderId()),
        updatedAt: Value(nowMs()),
        dirty: const Value(true),
      ),
    );
    if (body != null && syncEventNotes) {
      await _syncEventDescription(id, newBody);
    }
    if (body != null || title != null) await refreshLinks(id);
  }

  /// Keeps Events.notes in step when the canonical description note changes.
  /// Every live event linked to the note is updated, so a shared link cannot
  /// leave one row stale depending on query order. Only the narrow event.notes
  /// field is updated; the note is never recreated or cascaded, and
  /// soft-deleted events are left untouched.
  Future<void> _syncEventDescription(String noteId, String? body) async {
    final events =
        await (_db.select(_db.events)..where(
              (e) =>
                  e.notesOverflowNoteId.equals(noteId) & e.deletedAt.isNull(),
            ))
            .get();
    if (events.isEmpty) return;
    final now = nowMs();
    final notes = Value(NoteRepository.cappedEventNotes(body));
    await _db.transaction(() async {
      for (final event in events) {
        await (_db.update(
          _db.events,
        )..where((e) => e.id.equals(event.id))).write(
          EventsCompanion(
            notes: notes,
            updatedAt: Value(now),
            dirty: const Value(true),
          ),
        );
        await enqueueOutbox(
          _db,
          entity: 'event',
          entityId: event.id,
          op: 'update',
        );
      }
    });
  }

  /// Canonical description note for [eventId], created on first non-empty
  /// description. An empty description clears an existing note body but keeps
  /// the link and the note.
  ///
  /// When [mirrorEventNotes] is false the caller already wrote Events.notes
  /// (for example through `EventRepository.editOccurrence`), so updating the
  /// note body must not enqueue a second event update.
  Future<String?> ensureDescriptionNote(
    String eventId,
    String fullText, {
    bool mirrorEventNotes = true,
  }) async {
    final event = await (_db.select(
      _db.events,
    )..where((e) => e.id.equals(eventId))).getSingleOrNull();
    if (event == null) return null;
    Note? note;
    final linkedId = event.notesOverflowNoteId;
    if (linkedId != null) {
      final candidate = await getNote(linkedId);
      if (candidate != null && candidate.deletedAt == null) note = candidate;
    }
    String? noteId = note?.id;
    if (note == null) {
      if (fullText.isEmpty) {
        if (linkedId != null) {
          await (_db.update(_db.events)..where((e) => e.id.equals(eventId)))
              .write(const EventsCompanion(notesOverflowNoteId: Value(null)));
        }
        return null;
      }
      noteId = await createNote(
        title: 'Event description',
        body: fullText,
        linkedEventId: eventId,
      );
    } else if (note.body != fullText) {
      await updateNote(
        note.id,
        body: () => fullText,
        syncEventNotes: mirrorEventNotes,
      );
    }
    if (event.notesOverflowNoteId != noteId) {
      await (_db.update(_db.events)..where((e) => e.id.equals(eventId))).write(
        EventsCompanion(
          notesOverflowNoteId: Value(noteId),
          updatedAt: Value(nowMs()),
          dirty: const Value(true),
        ),
      );
    }
    return noteId;
  }

  /// Event behind [noteId]: the canonical description link first, then the
  /// note's linkedEventId. Soft-deleted rows are returned so callers can tell
  /// a deleted event from a missing one.
  Future<Event?> eventForNote(String noteId) async {
    // Live rows first, then oldest link, so a shared note resolves the same
    // way on every call instead of whichever row SQLite returns first.
    final canonical =
        await (_db.select(_db.events)
              ..where((e) => e.notesOverflowNoteId.equals(noteId))
              ..orderBy([
                (e) => OrderingTerm.asc(e.deletedAt),
                (e) => OrderingTerm.asc(e.createdAt),
                (e) => OrderingTerm.asc(e.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (canonical != null) return canonical;
    final note = await getNote(noteId);
    final eventId = note?.linkedEventId;
    if (eventId == null) return null;
    return (_db.select(
      _db.events,
    )..where((e) => e.id.equals(eventId))).getSingleOrNull();
  }

  Future<void> setPinned(String id, bool pinned) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        pinned: Value(pinned),
        updatedAt: Value(nowMs()),
        dirty: const Value(true),
      ),
    );
  }

  Future<String> duplicateNote(String id) async {
    final src = await getNote(id);
    if (src == null) throw StateError('note $id not found');
    return createNote(
      title: '${src.title} (copy)',
      body: src.body,
      folderId: src.folderId,
      linkedEventId: src.linkedEventId,
    );
  }

  Future<void> trashNote(String id) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deletedAt: Value(nowMs()),
        updatedAt: Value(nowMs()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> restoreNote(String id) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(nowMs()),
        dirty: const Value(true),
      ),
    );
  }

  Future<List<Note>> notesInFolder(String? folderId) {
    final q = _db.select(_db.notes)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.id.isNotInQuery(
              pendingIdsQuery(_db, entity: 'note', ops: const {'trash'}),
            ),
      );
    if (folderId == null) {
      q.where((t) => t.folderId.isNull());
    } else {
      q.where((t) => t.folderId.equals(folderId));
    }
    q.orderBy([
      (t) => OrderingTerm.desc(t.pinned),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);
    return q.get();
  }

  Stream<List<Note>> watchNotesInFolder(String? folderId) {
    final q = _db.select(_db.notes)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.id.isNotInQuery(
              pendingIdsQuery(_db, entity: 'note', ops: const {'trash'}),
            ),
      );
    if (folderId == null) {
      q.where((t) => t.folderId.isNull());
    } else {
      q.where((t) => t.folderId.equals(folderId));
    }
    q.orderBy([
      (t) => OrderingTerm.desc(t.pinned),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);
    return q.watch();
  }

  Future<List<Note>> notesForEvent(String eventId) {
    return (_db.select(_db.notes)
          ..where(
            (t) =>
                t.linkedEventId.equals(eventId) &
                t.deletedAt.isNull() &
                t.id.isNotInQuery(
                  pendingIdsQuery(_db, entity: 'note', ops: const {'trash'}),
                ),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Reactive variant of [notesForEvent] so event details can show a newly
  /// saved note without closing the sheet.
  Stream<List<Note>> watchNotesForEvent(String eventId) {
    return (_db.select(_db.notes)
          ..where(
            (t) =>
                t.linkedEventId.equals(eventId) &
                t.deletedAt.isNull() &
                t.id.isNotInQuery(
                  pendingIdsQuery(_db, entity: 'note', ops: const {'trash'}),
                ),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Stream<List<Note>> watchTrash() {
    return (_db.select(_db.notes)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .watch();
  }
}
