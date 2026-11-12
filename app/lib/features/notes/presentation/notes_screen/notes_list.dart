part of '../notes_screen.dart';

// Renders the folder/note list body for the notes screen.

class _NotesListBody extends ConsumerWidget {
  const _NotesListBody({
    required this.folders,
    required this.notes,
    required this.onFolderTap,
    required this.onNoteTap,
    required this.onNewNote,
  });

  final List<Folder> folders;
  final List<Note> notes;
  final ValueChanged<String> onFolderTap;
  final ValueChanged<Note> onNoteTap;
  final VoidCallback onNewNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (folders.isEmpty && notes.isEmpty) {
      return EmptyState(
        icon: Icons.note_outlined,
        title: 'No notes here',
        actionLabel: 'New note',
        onAction: onNewNote,
      );
    }
    final viewMode = ref.watch(notesViewModeProvider);
    final isGrid = viewMode == NotesViewMode.grid;
    if (!isGrid) {
      final rows = <Object>[...folders, ...notes];
      return RepaintBoundary(
        child: ListView.builder(
          key: const Key('notes-list'),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            if (row is Folder) return _folderTile(context, ref, row);
            return _noteTile(context, ref, row as Note);
          },
        ),
      );
    }
    return RepaintBoundary(
      child: CustomScrollView(
        key: const Key('notes-grid'),
        slivers: [
          if (folders.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _folderTile(context, ref, folders[i]),
                childCount: folders.length,
              ),
            ),
          if (notes.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _noteCard(context, ref, notes[i]),
                  childCount: notes.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columnsFor(context),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _columnsFor(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  Widget _folderTile(BuildContext context, WidgetRef ref, Folder folder) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(folder.name),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value != 'delete') return;
          final pending = ref.read(pendingOperationsProvider);
          final opId = await pending.scheduleFolderDelete(folder.id);
          if (!context.mounted) return;
          showUndoSnackBar(
            context,
            'Deleted folder "${folder.name}"',
            onUndo: () => pending.cancel(opId),
          );
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delete', child: Text('Delete folder')),
        ],
      ),
      onTap: () => onFolderTap(folder.id),
    );
  }

  Widget _noteTile(BuildContext context, WidgetRef ref, Note note) {
    final scheme = Theme.of(context).colorScheme;
    final title = note.title.isEmpty ? '(untitled)' : note.title;
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: scheme.onError),
      ),
      confirmDismiss: (_) async {
        final pending = ref.read(pendingOperationsProvider);
        final opId = await pending.scheduleNoteTrash(note.id);
        if (context.mounted) {
          showUndoSnackBar(
            context,
            'Trashed "$title"',
            onUndo: () => pending.cancel(opId),
          );
        }
        return false;
      },
      child: ListTile(
        leading: note.pinned ? const Icon(Icons.push_pin, size: 18) : null,
        tileColor: note.pinned
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
            : null,
        title: Text(title),
        subtitle: _noteSubtitle(note),
        onTap: () => onNoteTap(note),
      ),
    );
  }

  Widget _noteCard(BuildContext context, WidgetRef ref, Note note) {
    final scheme = Theme.of(context).colorScheme;
    final title = note.title.isEmpty ? '(untitled)' : note.title;
    final body = (note.body ?? '').trim();
    final sliced = body.length > 500 ? body.substring(0, 500) : body;
    final date = DeviceDateFormat.date(
      context,
      DateTime.fromMillisecondsSinceEpoch(note.updatedAt).toLocal(),
    );
    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey('card-${note.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          color: scheme.error,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: Icon(Icons.delete, color: scheme.onError),
        ),
        confirmDismiss: (_) async {
          final pending = ref.read(pendingOperationsProvider);
          final opId = await pending.scheduleNoteTrash(note.id);
          if (context.mounted) {
            showUndoSnackBar(
              context,
              'Trashed "$title"',
              onUndo: () => pending.cancel(opId),
            );
          }
          return false;
        },
        child: Card(
          clipBehavior: Clip.antiAlias,
          color: note.pinned
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
              : null,
          child: InkWell(
            onTap: () => onNoteTap(note),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (note.pinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin, size: 14),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ClipRect(
                      child: IgnorePointer(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: MarkdownBody(
                            body: sliced,
                            compact: true,
                            interactive: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget? _noteSubtitle(Note n) {
  final body = (n.body ?? '').trim();
  if (body.isEmpty && n.linkedEventId == null) return null;
  final first = body
      .split('\n')
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final text = n.linkedEventId != null ? '[event] $first' : first;
  if (text.isEmpty) return null;
  return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
}
