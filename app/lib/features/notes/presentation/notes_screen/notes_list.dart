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
    final strings = NotesStrings.of(context);
    if (folders.isEmpty && notes.isEmpty) {
      return SingleChildScrollView(
        child: AppEmptyState(
          icon: Icons.note_outlined,
          title: strings.emptyTitle,
          message: strings.emptyMessage,
          actionLabel: strings.newNote,
          onAction: onNewNote,
        ),
      );
    }
    final viewMode = ref.watch(notesViewModeProvider);
    if (viewMode == NotesViewMode.list) return _list(context, ref);
    return _grid(context, ref);
  }

  Widget _list(BuildContext context, WidgetRef ref) {
    final rows = <Object>[...folders, ...notes];
    return RepaintBoundary(
      child: ListView.builder(
        key: const Key('notes-list'),
        padding: const EdgeInsets.only(bottom: DsSpace.x24),
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final row = rows[i];
          final child = row is Folder
              ? _folderRow(context, ref, row)
              : _NoteTiles.row(context, ref, row as Note, onNoteTap);
          return Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.x8),
            child: child,
          );
        },
      ),
    );
  }

  Widget _grid(BuildContext context, WidgetRef ref) {
    return RepaintBoundary(
      child: CustomScrollView(
        key: const Key('notes-grid'),
        slivers: [
          if (folders.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(bottom: DsSpace.x8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.x8),
                    child: _folderRow(context, ref, folders[i]),
                  ),
                  childCount: folders.length,
                ),
              ),
            ),
          if (notes.isNotEmpty)
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) =>
                    _NoteTiles.card(context, ref, notes[i], onNoteTap),
                childCount: notes.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columnsFor(context),
                mainAxisSpacing: DsSpace.x8,
                crossAxisSpacing: DsSpace.x8,
                mainAxisExtent: _cardExtent(context),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: DsSpace.x24)),
        ],
      ),
    );
  }

  int _columnsFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  /// Grows card height with text scale so 200% labels never overflow the grid.
  double _cardExtent(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return 196 * scale.clamp(1.0, 1.8);
  }

  Widget _folderRow(BuildContext context, WidgetRef ref, Folder folder) {
    final theme = Theme.of(context);
    final strings = NotesStrings.of(context);
    return AppSurface(
      onTap: () => onFolderTap(folder.id),
      padding: const EdgeInsets.fromLTRB(
        DsSpace.x12,
        DsSpace.x4,
        DsSpace.x4,
        DsSpace.x4,
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_outlined,
            size: DsIcon.md,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: DsSpace.x12),
          Expanded(
            child: Text(
              folder.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: strings.folderActions,
            onSelected: (value) async {
              if (value != 'delete') return;
              final pending = ref.read(pendingOperationsProvider);
              final opId = await pending.scheduleFolderDelete(folder.id);
              if (!context.mounted) return;
              showUndoSnackBar(
                context,
                strings.deletedFolder(folder.name),
                onUndo: () => pending.cancel(opId),
              );
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'delete', child: Text(strings.deleteFolder)),
            ],
          ),
        ],
      ),
    );
  }
}
