part of '../notes_screen.dart';

// Notes screen view and state.

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key, this.linkedEventId});

  /// When set, the screen creates/lists notes linked to an event.
  final String? linkedEventId;

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String? _folderId;
  String _query = '';
  bool _folderRestored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_folderRestored) {
      _folderRestored = true;
      Future.microtask(() async {
        try {
          final repo = await ref.read(settingsRepositoryProvider.future);
          final saved = repo.selectedNotesFolderId;
          if (saved != _folderId && mounted) {
            setState(() => _folderId = saved);
          }
          ref.read(selectedFolderProvider.notifier).select(saved);
        } catch (_) {}
      });
    }
  }

  Future<void> _navigateFolder(String? id) async {
    setState(() => _folderId = id);
    ref.read(selectedFolderProvider.notifier).select(id);
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.setSelectedNotesFolderId(id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersProvider(_folderId));
    final notesAsync = ref.watch(folderNotesProvider(_folderId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => _search(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (value) {
              switch (value) {
                case 'trash':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _TrashScreen(),
                    ),
                  );
                case 'export':
                  _exportZip();
                case 'import':
                  _importFiles();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'trash', child: Text('Trash')),
              PopupMenuItem(value: 'export', child: Text('Export ZIP')),
              PopupMenuItem(value: 'import', child: Text('Import .md / .txt')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _Breadcrumbs(
            folderId: _folderId,
            onNavigate: (id) => _navigateFolder(id),
          ),
          Expanded(
            child: foldersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: 'Could not load folders.',
                onRetry: () => ref.invalidate(foldersProvider(_folderId)),
              ),
              data: (folders) => notesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  message: 'Could not load notes.',
                  onRetry: () => ref.invalidate(folderNotesProvider(_folderId)),
                ),
                data: (notes) => _NotesListBody(
                  folders: folders,
                  notes: notes,
                  onFolderTap: _navigateFolder,
                  onNoteTap: _openNote,
                  onNewNote: _newNote,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'new-folder',
            onPressed: _newFolder,
            child: const Icon(Icons.create_new_folder_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'new-note',
            onPressed: _newFromTemplate,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Future<void> _newNote({String template = ''}) async {
    final repo = ref.read(noteRepositoryProvider);
    final id = await repo.createNote(
      title: template.isEmpty ? '' : 'Meeting notes',
      body: template.isEmpty ? null : template,
      folderId: _folderId,
      linkedEventId: widget.linkedEventId,
    );
    if (mounted) _openById(id);
  }

  Future<void> _newFromTemplate() async {
    final choice = await showAppSheet<String>(
      context,
      builder: (ctx) => EscapeToClose(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Blank'),
                onTap: () => Navigator.of(ctx).pop('blank'),
              ),
              ListTile(
                title: const Text('Meeting notes'),
                onTap: () => Navigator.of(ctx).pop('meeting'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == 'meeting') {
      await _newNote(
        template: '## Attendees\n\n- \n\n## Agenda\n\n- \n\n## Notes\n\n',
      );
    } else if (choice == 'blank') {
      await _newNote();
    }
  }

  void _openNote(Note n) => _openById(n.id);

  void _openById(String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteEditorScreen(noteId: id)),
    );
  }

  Future<void> _importFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt'],
      );
      if (files.isEmpty) return;
      final repo = ref.read(noteRepositoryProvider);
      var count = 0;
      for (final f in files) {
        if (f.path != null) {
          await repo.importMarkdownFile(f.path!, folderId: _folderId);
          count++;
        } else {
          final bytes = await f.readAsBytes();
          final id = await repo.createNote(
            title: f.name.contains('.')
                ? f.name.substring(0, f.name.lastIndexOf('.'))
                : f.name,
            body: utf8.decode(bytes, allowMalformed: true),
            folderId: _folderId,
          );
          if (id.isNotEmpty) count++;
        }
      }
      if (mounted) {
        showAppSnackBar(
          context,
          count == 0 ? 'No files imported' : 'Imported $count file(s)',
          icon: Icons.upload_file_outlined,
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Import failed: $e');
      }
    }
  }

  Future<void> _exportZip() async {
    try {
      final notes = ref.read(folderNotesProvider(_folderId)).value ?? const [];
      final archive = Archive();
      for (final n in notes) {
        final name = (n.title.isEmpty ? 'untitled' : n.title).replaceAll(
          RegExp(r'[\\\\/:*?"<>|]'),
          '_',
        );
        final body = n.body ?? '';
        archive.addFile(ArchiveFile('$name.md', body.length, body.codeUnits));
      }
      final data = ZipEncoder().encode(archive);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/notes-export.zip');
      await file.writeAsBytes(data);
      if (mounted) {
        showAppSnackBar(
          context,
          'Exported to ${file.path}',
          icon: Icons.archive_outlined,
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Export failed: $e');
      }
    }
  }

  Future<void> _newFolder() async {
    final name = await showPromptDialog(
      context,
      title: 'New folder',
      hint: 'Name',
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(noteRepositoryProvider)
          .createFolder(name, parentId: _folderId);
    }
  }

  Future<void> _search(BuildContext context) async {
    final query = await showDialog<String>(
      context: context,
      builder: (_) => _SearchDialog(initialQuery: _query),
    );
    if (query == null || query.isEmpty || !mounted) return;
    setState(() => _query = query);
    final hits = await ref.read(noteRepositoryProvider).searchNotes(query);
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _SearchResults(query: query, hits: hits, onOpen: _openById),
      ),
    );
  }
}

/// Owns the search field controller so it outlives the dialog route's exit
/// animation and is disposed with the route state.
class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.initialQuery});

  final String initialQuery;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search notes'),
      content: TextField(
        key: const Key('notes-search-field'),
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search notes',
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
            onPressed: () {
              AppFeedback.tap();
              _controller.clear();
            },
          ),
        ),
        onSubmitted: (value) {
          final query = value.trim();
          if (query.isEmpty) return;
          AppFeedback.selection();
          Navigator.of(context).pop(query);
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            AppFeedback.tap();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final query = value.text.trim();
            return FilledButton(
              onPressed: query.isEmpty
                  ? null
                  : () {
                      AppFeedback.selection();
                      Navigator.of(context).pop(query);
                    },
              child: const Text('Search'),
            );
          },
        ),
      ],
    );
  }
}
