// Global search providers: one query across tasks, events, notes,
// habits, countdowns and tags. Empty query returns no rows.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/db_provider.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/repositories/countdown_repository.dart';
import '../../../data/repositories/event_repository.dart';
import '../../../data/repositories/habit_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/repositories/occurrence_repository.dart';
import '../../../data/repositories/task_repository.dart';

enum SearchScope { all, tasks, events, notes, habits, countdowns, tags }

/// One run of a note search snippet. [bold] marks a query match.
class SearchSnippetSpan {
  const SearchSnippetSpan(this.text, {this.bold = false});

  final String text;
  final bool bold;
}

/// Splits [snippet] into runs, bolding every case-insensitive occurrence of
/// [query]. All other text, including literal `<b>` markers, is preserved.
List<SearchSnippetSpan> highlightSnippet(String snippet, String query) {
  if (query.isEmpty) return [SearchSnippetSpan(snippet)];

  final lowerSnippet = snippet.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <SearchSnippetSpan>[];
  var start = 0;
  while (true) {
    final index = lowerSnippet.indexOf(lowerQuery, start);
    if (index < 0) break;
    if (index > start) {
      spans.add(SearchSnippetSpan(snippet.substring(start, index)));
    }
    final end = index + query.length;
    spans.add(SearchSnippetSpan(snippet.substring(index, end), bold: true));
    start = end;
  }
  if (start < snippet.length) {
    spans.add(SearchSnippetSpan(snippet.substring(start)));
  }
  return spans.isEmpty ? [SearchSnippetSpan(snippet)] : spans;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final searchScopeProvider = NotifierProvider<SearchScopeNotifier, SearchScope>(
  SearchScopeNotifier.new,
);

class SearchScopeNotifier extends Notifier<SearchScope> {
  @override
  SearchScope build() => SearchScope.all;

  void set(SearchScope scope) => state = scope;
}

final _taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(appDatabaseProvider));
});

final _eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(
    ref.watch(appDatabaseProvider),
    OccurrenceRepository(ref.watch(appDatabaseProvider)),
  );
});

final _noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(appDatabaseProvider));
});

final _habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(appDatabaseProvider));
});

final _countdownRepositoryProvider = Provider<CountdownRepository>((ref) {
  return CountdownRepository(ref.watch(appDatabaseProvider));
});

final searchTasksProvider = FutureProvider<List<Task>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty) return [];
  return ref.watch(_taskRepositoryProvider).searchTasks(q);
});

final searchEventsProvider = FutureProvider<List<Event>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty) return [];
  return ref.watch(_eventRepositoryProvider).searchEvents(q);
});

final searchNotesProvider = FutureProvider<List<NoteSearchHit>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty) return [];
  final hits = await ref.watch(_noteRepositoryProvider).searchNotes(q);
  return hits.take(20).toList();
});

final searchHabitsProvider = FutureProvider<List<Habit>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty) return [];
  return ref.watch(_habitRepositoryProvider).searchHabits(q);
});

final searchCountdownsProvider = FutureProvider<List<Countdown>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty) return [];
  return ref.watch(_countdownRepositoryProvider).searchCountdowns(q);
});

final searchTagsProvider = FutureProvider<List<Tag>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty) return [];
  return ref.watch(_taskRepositoryProvider).searchTags(q);
});

/// Open tasks carrying [tagId], used by the tag result sheet.
final searchTasksForTagProvider = FutureProvider.family<List<Task>, String>((
  ref,
  tagId,
) {
  return ref.watch(_taskRepositoryProvider).searchTasksForTag(tagId);
});
