part of '../event_details_sheet.dart';

/// Event detail content: title, source, metadata, attendees and actions.
class _EventDetailsBody extends ConsumerWidget {
  const _EventDetailsBody({
    required this.event,
    required this.source,
    required this.isMicrosoft,
    required this.onReload,
  });

  final Event event;
  final String? source;
  final bool isMicrosoft;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event;
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
              onTap: isMicrosoft
                  ? null
                  : () async {
                      final moved = await pickAndMoveEvent(
                        context,
                        ref,
                        eventId: e.id,
                        currentCalendarId: e.calendarId,
                      );
                      if (moved && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
            ),
            if (e.location != null && e.location!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(e.location!),
              ),
            if (e.meetUrl != null && e.meetUrl!.isNotEmpty)
              _MeetTile(url: e.meetUrl!),
            if (e.notes != null && e.notes!.isNotEmpty)
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
                    Expanded(child: MarkdownBody(body: e.notes!)),
                  ],
                ),
              ),
            _Attendees(eventId: e.id),
            _LinkedNotes(eventId: e.id),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await showEventEditor(context, event: e);
                        if (context.mounted) onReload();
                      },
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _delete(context, ref, e),
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

class _MeetTile extends StatelessWidget {
  const _MeetTile({required this.url});

  final String url;

  Future<void> _open(BuildContext context) async {
    final ok = await SystemLauncher.openUrl(url);
    var copied = true;
    if (!ok) {
      try {
        await Clipboard.setData(ClipboardData(text: url));
      } catch (_) {
        copied = false;
      }
    }
    if (!context.mounted) return;
    final message = ok
        ? 'Opening meeting'
        : copied
        ? 'Join not supported here - link copied'
        : 'Join not supported here - could not copy link';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(BuildContext context) async {
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: url));
    } catch (_) {
      copied = false;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copied ? 'Meet link copied' : 'Could not copy link'),
      ),
    );
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
          onTap: () => _copy(context),
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
