# Note editor

## Inline Markdown editing

Edit mode uses a single body field. `MarkdownEditingController`
(`app/lib/features/notes/presentation/markdown_editing_controller.dart`)
overrides `buildTextSpan` to style the raw Markdown in place:

- headings `#` to `######`
- bold `**` and `__`
- italic `*` and `_`
- bold-italic `***` and `___`
- inline code and fenced code blocks
- strikethrough `~~`
- links `[text](url)`
- blockquotes, bullets, numbered lists, and task checkboxes

Syntax markers stay visible but are dimmed. The concatenated span text always
equals `TextEditingController.text`, so cursor, selection, and IME offsets stay
correct. Parsed spans are cached per text and composing ranges are underlined.

Storage remains plain Markdown. Read mode continues to use the rendered
`MarkdownPreview`. No rich-text dependency is used.

## Event descriptions as linked notes

Every event description is mirrored to a canonical Ephemeron note. Its id is
stored in `Events.notesOverflowNoteId`; no extra column or migration is used.
`NoteRepository.ensureDescriptionNote(eventId, fullText)` reuses that note when
it is live, updates the body when it differs, and otherwise creates a note
titled "Event description" linked to the event. An empty description clears the
note body and keeps the note and link; it never trashes the note.

`Events.notes` keeps the 8000-character capped value for Google sync while the
linked note keeps the full text. The event editor loads the full body from the
canonical note so long descriptions are not truncated while editing. Saving an
event syncs the trimmed description to the note for the returned affected id
(created event, exception, split master, or master).

Reverse sync: `NoteRepository.updateNote` also updates the linked event when the
edited note is referenced by `Events.notesOverflowNoteId`. It writes the capped
body to `Events.notes`, marks the event dirty, and enqueues a normal `event`
update for Google description sync. It never creates another note.

Deletion does not cascade. Trashing a note leaves the event description text
and link intact; event details shows a compact "Linked note not found"
indicator when the canonical note is trashed or missing. Soft-deleting an event
leaves the linked note intact; the note editor shows "Linked event not found"
when its linked event is deleted or absent.

Recurring occurrences resolve their exception before showing details. Calendar
call sites pass the occurrence start to `showEventDetails`; the repository
selects the live, non-cancelled exception matching `originalStart` or `startUtc`
and otherwise falls back to the master. Details, edit, and delete then operate
on the resolved row. The canonical description note is excluded from the
linked-note list to avoid showing it twice.

## Event notes

Event details stays open while the event editor or note editor is pushed on top.
Returning reloads the event and the linked note list. `NoteRepository`
exposes both:

- `notesForEvent(eventId)` for one-shot reads
- `watchNotesForEvent(eventId)` for reactive lists

The Add note button creates a linked note and opens it without closing event
details. Tapping a linked note does the same. A saved note appears immediately
through the reactive stream.

## Back navigation

The note editor flushes pending autosave before leaving. Back navigation sets
an allow-pop flag, rebuilds `PopScope`, then pops once after the frame so the
same `PopScope` cannot block the programmatic pop.
