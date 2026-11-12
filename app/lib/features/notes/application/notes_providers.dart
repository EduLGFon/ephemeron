// Riverpod providers for notes. UI reads only from Drift streams.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/db_provider.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/repositories/note_repository.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(appDatabaseProvider));
});

final foldersProvider = StreamProvider.family<List<Folder>, String?>((
  ref,
  parentId,
) {
  return ref.watch(noteRepositoryProvider).watchChildFolders(parentId);
});

final folderNotesProvider = StreamProvider.family<List<Note>, String?>((
  ref,
  folderId,
) {
  return ref.watch(noteRepositoryProvider).watchNotesInFolder(folderId);
});

final noteTrashProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(noteRepositoryProvider).watchTrash();
});

/// Notes linked to one event; reactive so event details update after the
/// note editor closes.
final eventNotesProvider = StreamProvider.family<List<Note>, String>((
  ref,
  eventId,
) {
  return ref.watch(noteRepositoryProvider).watchNotesForEvent(eventId);
});

/// Null means the top level (unfiled notes).
final selectedFolderProvider = NotifierProvider<SelectedFolder, String?>(
  SelectedFolder.new,
);

class SelectedFolder extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

enum NotesViewMode { grid, list }

/// Persisted notes list view mode: grid (default) or list.
final notesViewModeProvider =
    NotifierProvider<NotesViewModeNotifier, NotesViewMode>(
      NotesViewModeNotifier.new,
    );

class NotesViewModeNotifier extends Notifier<NotesViewMode> {
  static const key = 'notes.viewMode';

  int _generation = 0;

  @override
  NotesViewMode build() {
    final g = ++_generation;
    _load(g);
    return NotesViewMode.grid;
  }

  Future<void> _load(int g) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(key);
      final mode = saved == 'list' ? NotesViewMode.list : NotesViewMode.grid;
      if (g == _generation && mode != state) state = mode;
    } catch (_) {}
  }

  Future<void> setMode(NotesViewMode mode) async {
    _generation++;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, mode == NotesViewMode.list ? 'list' : 'grid');
    } catch (_) {}
  }
}
