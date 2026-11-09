part of '../../event_editor_sheet.dart';

extension on _EventEditorState {
  Future<void> _clearDraftAfterSave() async {
    _saved = true;
    try {
      await ref.read(draftStoreProvider).clear('event', _draftEntityId);
      final srepo = await ref.read(settingsRepositoryProvider.future);
      final expected = widget.event == null
          ? 'event_new'
          : 'event:${widget.event!.id}';
      if (srepo.openSheet == expected) await srepo.setOpenSheet(null);
    } catch (_) {}
  }

  /// Trims the description and caps the event column so the full text can
  /// live in the linked description note.
  ({String? full, String? stored}) _notesPayload() {
    final full = _notes.text.trim();
    if (full.isEmpty) return (full: null, stored: null);
    return (full: full, stored: NoteRepository.cappedEventNotes(full));
  }

  /// Every description is mirrored to the canonical linked note, not only
  /// overflow text. An empty description clears the note body, keeping the
  /// note and its link.
  Future<void> _syncDescription(String eventId, String? fullNotes) async {
    await ref
        .read(noteRepositoryProvider)
        .ensureDescriptionNote(eventId, fullNotes ?? '');
  }
}
