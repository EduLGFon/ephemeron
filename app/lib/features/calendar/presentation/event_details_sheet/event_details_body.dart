part of '../event_details_sheet.dart';

/// Event detail content: title, source, metadata, attendees and actions.
class _EventDetailsBody extends ConsumerWidget {
  const _EventDetailsBody({
    required this.event,
    required this.source,
    required this.isMicrosoft,
    required this.readOnly,
    required this.onReload,
    this.occurrenceStartMs,
    this.descriptionNote,
  });

  final Event event;
  final String? source;
  final bool isMicrosoft;
  final bool readOnly;
  final int? occurrenceStartMs;
  final VoidCallback onReload;
  final Note? descriptionNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event;
    final locked = readOnly;
    final description = descriptionNote?.body ?? e.notes;
    final descriptionNoteMissing =
        e.notesOverflowNoteId != null && descriptionNote == null;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(
                e.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(_when(context, e)),
            ),
            _SourceTile(
              icon: Icons.calendar_today_outlined,
              kind: 'Calendar',
              label: source ?? 'Unknown calendar',
              onTap: isMicrosoft || locked
                  ? null
                  : () async {
                      final container = ProviderScope.containerOf(
                        context,
                        listen: false,
                      );
                      final repo = ref.read(eventRepositoryProvider);
                      final masterId = e.recurringMasterId;
                      final seriesId = masterId ?? e.id;
                      final master = masterId == null
                          ? null
                          : await repo.getEvent(masterId);
                      if (!context.mounted) return;
                      final originCalendarId =
                          master?.calendarId ?? e.calendarId;
                      final moved = await pickAndMoveEvent(
                        context,
                        ref,
                        eventId: seriesId,
                        currentCalendarId: originCalendarId,
                      );
                      if (!moved || !context.mounted) return;
                      AppFeedback.tap();
                      showUndoSnackBar(
                        context,
                        'Event moved',
                        onUndo: () async {
                          try {
                            await repo.moveEventToCalendar(
                              seriesId,
                              originCalendarId,
                            );
                            container
                                .read(occurrenceDirtyProvider.notifier)
                                .markDirty();
                            container.invalidate(occurrenceSourceMapProvider);
                          } catch (_) {
                            // The move already happened; undo is best effort.
                          }
                        },
                      );
                      Navigator.of(context).pop();
                    },
            ),
            if (locked)
              const ListTile(
                key: Key('read-only-calendar'),
                leading: Icon(Icons.lock_outline),
                title: Text('Read-only calendar'),
                subtitle: Text(
                  'Editing, deleting, and moving are unavailable.',
                ),
                dense: true,
              ),
            if (e.location != null && e.location!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(e.location!),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openLocation(context, e.location!),
              ),
            if (e.meetUrl != null && e.meetUrl!.isNotEmpty)
              _MeetTile(url: e.meetUrl!),
            if (description != null && description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.notes_outlined),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: MarkdownBody(body: description)),
                  ],
                ),
              ),
            if (descriptionNoteMissing)
              const ListTile(
                key: Key('description-note-missing'),
                dense: true,
                leading: Icon(Icons.link_off),
                title: Text('Linked note not found'),
              ),
            _Attendees(eventId: e.id),
            _LinkedNotes(eventId: e.id, excludeNoteId: e.notesOverflowNoteId),
            EntityCountdownSection(
              linkedType: 'event',
              linkedId: e.id,
              initialTitle: e.title,
              initialDate: _countdownInitialDate(e, occurrenceStartMs),
            ),
            if (!locked)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await showEventEditor(
                            context,
                            event: e,
                            occurrenceStartMs: occurrenceStartMs,
                          );
                          if (context.mounted) onReload();
                        },
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _delete(
                          context,
                          ref,
                          e,
                          occurrenceStartMs: occurrenceStartMs,
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final noteRepo = ref.read(noteRepositoryProvider);
                  final id = await noteRepo.createNote(
                    title: 'Notes for ${e.title}',
                    linkedEventId: e.id,
                  );
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NoteEditorScreen(noteId: id),
                    ),
                  );
                  if (context.mounted) onReload();
                },
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Add note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Initial countdown date: occurrence date when opened from the calendar,
/// otherwise the event's own local start date. All-day cache timestamps are
/// UTC date keys, so they are not converted to device-local time.
DateTime? _countdownInitialDate(Event e, int? occurrenceStartMs) {
  if (e.isAllDay) {
    if (occurrenceStartMs != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(
        occurrenceStartMs,
        isUtc: true,
      );
      return DateTime(d.year, d.month, d.day);
    }
    return parseCountdownDate(e.startDate);
  }
  final ms = occurrenceStartMs ?? e.startUtc;
  if (ms == null) return null;
  final local = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  return DateTime(local.year, local.month, local.day);
}

Future<void> _openLocation(BuildContext context, String location) async {
  final url = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': location,
  }).toString();
  final ok = await SystemLauncher.openUrl(url);
  if (!context.mounted) return;
  if (ok) {
    AppFeedback.tap();
    return;
  }
  showAppSnackBar(context, 'Could not open maps', icon: Icons.map_outlined);
}

class _MeetTile extends StatelessWidget {
  const _MeetTile({required this.url});

  final String url;

  Future<void> _open(BuildContext context) async {
    final ok = await SystemLauncher.openUrl(url);
    if (!context.mounted) return;
    if (ok) {
      AppFeedback.tap();
      showAppSnackBar(
        context,
        'Opening meeting',
        icon: Icons.videocam_outlined,
      );
    } else {
      showAppSnackBar(
        context,
        'Could not open link',
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: url));
    } catch (_) {
      copied = false;
    }
    if (!context.mounted) return;
    if (copied) {
      AppFeedback.tap();
      showAppSnackBar(context, 'Link copied', icon: Icons.link);
    } else {
      AppFeedback.error();
      showAppSnackBar(
        context,
        'Could not copy link',
        icon: Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.videocam_outlined),
          title: Text(url),
          subtitle: const Text('Google Meet'),
          onTap: () => _open(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _open(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Join'),
              ),
              TextButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy link'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
