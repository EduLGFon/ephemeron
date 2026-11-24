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
    final strings = NotesStrings.of(context);
    final foldersAsync = ref.watch(foldersProvider(_folderId));
    final notesAsync = ref.watch(folderNotesProvider(_folderId));
    final viewMode = ref.watch(notesViewModeProvider);
    final noteCount = notesAsync.value?.length;

    return AppPage(
      header: AppPageHeader(
        title: Text(strings.title),
        subtitle: noteCount == null ? null : Text(strings.noteCount(noteCount)),
        actions: <Widget>[
          AppIconButton(
            key: const ValueKey('notes-search'),
            icon: Icons.search,
            tooltip: strings.search,
            semanticLabel: strings.search,
            onPressed: () => context.push('/search'),
          ),
          AppIconButton(
            icon: Icons.note_add_outlined,
            tooltip: strings.newNote,
            onPressed: () => _newFromTemplate(),
          ),
          AppIconButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: strings.newFolder,
            onPressed: _newFolder,
          ),
          AppIconButton(
            icon: Icons.delete_outline,
            tooltip: strings.trash,
            onPressed: _openTrash,
          ),
          AppIconButton(
            icon: viewMode == NotesViewMode.grid
                ? Icons.view_list
                : Icons.grid_view,
            tooltip: viewMode == NotesViewMode.grid
                ? strings.listView
                : strings.gridView,
            onPressed: () => ref
                .read(notesViewModeProvider.notifier)
                .setMode(
                  viewMode == NotesViewMode.grid
                      ? NotesViewMode.list
                      : NotesViewMode.grid,
                ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: strings.more,
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportZip();
                case 'import':
                  _importFiles();
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'export', child: Text(strings.exportZip)),
              PopupMenuItem(value: 'import', child: Text(strings.importFiles)),
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Breadcrumbs(
            folderId: _folderId,
            onNavigate: (id) => _navigateFolder(id),
          ),
          const SizedBox(height: DsSpace.x8),
          Expanded(
            child: foldersAsync.when(
              loading: () => const AppSkeletonList(rows: 5),
              error: (e, _) => _ErrorState(
                message: strings.errorFolders,
                onRetry: () => ref.invalidate(foldersProvider(_folderId)),
              ),
              data: (folders) => notesAsync.when(
                loading: () => const AppSkeletonList(rows: 5),
                error: (e, _) => _ErrorState(
                  message: strings.errorNotes,
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
    );
  }

  void _openTrash() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const _TrashScreen()));
  }

  Future<void> _newNote({String template = ''}) async {
    final repo = ref.read(noteRepositoryProvider);
    final id = await repo.createNote(
      title: template.isEmpty ? '' : NotesStrings.of(context).meetingNote,
      body: template.isEmpty ? null : template,
      folderId: _folderId,
      linkedEventId: widget.linkedEventId,
    );
    if (mounted) _openById(id);
  }

  Future<void> _newFromTemplate() async {
    final strings = NotesStrings.of(context);
    final choice = await showAppSheet<String>(
      context,
      builder: (ctx) => EscapeToClose(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.x16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSheetHeader(title: strings.templateSheetTitle),
                _TemplateOption(
                  icon: Icons.note_add_outlined,
                  label: strings.blankNote,
                  onTap: () => Navigator.of(ctx).pop('blank'),
                ),
                _TemplateOption(
                  icon: Icons.groups_outlined,
                  label: strings.meetingNote,
                  onTap: () => Navigator.of(ctx).pop('meeting'),
                ),
              ],
            ),
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
    final strings = NotesStrings.of(context);
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
          count == 0 ? strings.noFilesImported : strings.importedFiles(count),
          icon: Icons.upload_file_outlined,
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, strings.importFailed('$e'));
      }
    }
  }

  Future<void> _exportZip() async {
    final strings = NotesStrings.of(context);
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
          strings.exportedTo(file.path),
          icon: Icons.archive_outlined,
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, strings.exportFailed('$e'));
      }
    }
  }

  Future<void> _newFolder() async {
    final strings = NotesStrings.of(context);
    final name = await showPromptDialog(
      context,
      title: strings.newFolder,
      hint: strings.folderNameHint,
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(noteRepositoryProvider)
          .createFolder(name, parentId: _folderId);
    }
  }
}
