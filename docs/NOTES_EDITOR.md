# Note editor

## Inline Markdown editing
Edit mode uses single body field. MarkdownEditingController (app/lib/features/notes/presentation/markdown_editing_controller.dart) overrides buildTextSpan to style raw Markdown in place: headings, bold, italic, bold-italic, inline/fenced code, strikethrough, links, blockquotes, bullets, numbered lists, task checkboxes. Syntax markers stay visible but dimmed. Concatenated span text always equals TextEditingController.text, so cursor/selection/IME offsets stay correct. Parsed spans cached per text; composing ranges underlined. Storage stays plain Markdown. Read mode uses rendered MarkdownPreview. No rich-text dependency.

## Event descriptions as linked notes
Every event description mirrored to canonical Ephemeron note. Id stored in Events.notesOverflowNoteId; no extra column/migration. NoteRepository.ensureDescriptionNote(eventId, fullText) reuses live note, updates body if differs, else creates note titled "Event description" linked to event. Empty description clears note body, keeps note/link; never trashes note.

Events.notes keeps 8000-char capped value for Google sync; linked note keeps full text. Event editor loads full body from canonical note so long descriptions not truncated while editing. Saving event syncs trimmed description to note for returned affected id (created event, exception, split master, or master).

Reverse sync: NoteRepository.updateNote also updates linked event when edited note referenced by Events.notesOverflowNoteId. Writes capped body to Events.notes, marks event dirty, enqueues normal event update for Google description sync. Never creates another note.

Deletion does not cascade. Trashing note leaves event description text and link intact; event details shows compact "Linked note not found" when canonical note trashed/missing. Soft-deleting event leaves linked note intact; note editor shows "Linked event not found" when linked event deleted/absent.

Recurring occurrences resolve exception before showing details. Calendar call sites pass occurrence start to showEventDetails; repository selects live non-cancelled exception matching originalStart or startUtc, else falls back to master. Details/edit/delete operate on resolved row. Canonical description note excluded from linked-note list to avoid duplicate.

## Event notes
Event details stays open while event editor or note editor pushed on top. Returning reloads event and linked note list. NoteRepository exposes notesForEvent (one-shot) and watchNotesForEvent (reactive). Add note button creates linked note and opens without closing details. Tapping linked note same. Saved note appears immediately via reactive stream.

## Back navigation
Note editor flushes pending autosave before leaving. Back sets allow-pop flag, rebuilds PopScope, then pops once after frame so same PopScope cannot block programmatic pop.