// User-visible strings for the Notes home, search and trash chrome. English
// only for now; typed getters keep widget code free of hardcoded copy and give
// future locales one place to extend.
import 'package:material_ui/material_ui.dart';

class NotesStrings {
  const NotesStrings(this.locale);

  final Locale locale;

  static NotesStrings of(BuildContext context) =>
      NotesStrings(Localizations.localeOf(context));

  String get title => 'Notes';
  String get search => 'Search';
  String get searchNotes => 'Search notes';
  String get cancel => 'Cancel';
  String get back => 'Back';
  String get newNote => 'New note';
  String get newFolder => 'New folder';
  String get folderNameHint => 'Name';
  String get trash => 'Trash';
  String get exportZip => 'Export ZIP';
  String get importFiles => 'Import .md / .txt';
  String get more => 'More';
  String get listView => 'List view';
  String get gridView => 'Grid view';
  String get allNotes => 'All notes';
  String get errorFolders => 'Could not load folders.';
  String get errorNotes => 'Could not load notes.';
  String get errorTrash => 'Could not load trash.';
  String get emptyTitle => 'No notes here';
  String get emptyMessage =>
      'Create a note, or add a folder to keep things together.';
  String get untitled => '(untitled)';
  String get pinned => 'Pinned';
  String get folderActions => 'Folder actions';
  String get deleteFolder => 'Delete folder';
  String get restore => 'Restore';
  String restoreNote(String title) => 'Restore "$title"';
  String get trashEmptyTitle => 'Trash is empty';
  String get trashEmptyMessage => 'Deleted notes stay here until restored.';
  String get blankNote => 'Blank';
  String get meetingNote => 'Meeting notes';
  String get templateSheetTitle => 'New note';
  String get noFilesImported => 'No files imported';
  String get linkedEventPrefix => '[event]';

  String resultsFor(String query) => 'Results for "$query"';
  String get noMatchesTitle => 'No matches';
  String nothingMatched(String query) => 'Nothing matched "$query".';
  String noteCount(int count) => count == 1 ? '1 note' : '$count notes';
  String trashed(String title) => 'Trashed "$title"';
  String deletedFolder(String name) => 'Deleted folder "$name"';
  String importedFiles(int count) => 'Imported $count file(s)';
  String exportedTo(String path) => 'Exported to $path';
  String importFailed(String error) => 'Import failed: $error';
  String exportFailed(String error) => 'Export failed: $error';
}
