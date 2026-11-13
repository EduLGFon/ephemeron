part of '../search_screen.dart';

bool _show(SearchScope scope, SearchScope s) =>
    scope == SearchScope.all || scope == s;

class _Results extends ConsumerWidget {
  const _Results({
    required this.scope,
    required this.l,
    required this.query,
    required this.onClear,
  });

  final SearchScope scope;
  final AppLocalizations l;
  final String query;
  final Future<void> Function() onClear;

  void _retry(WidgetRef ref) {
    if (_show(scope, SearchScope.tasks)) ref.invalidate(searchTasksProvider);
    if (_show(scope, SearchScope.events)) ref.invalidate(searchEventsProvider);
    if (_show(scope, SearchScope.notes)) ref.invalidate(searchNotesProvider);
    if (_show(scope, SearchScope.habits)) ref.invalidate(searchHabitsProvider);
    if (_show(scope, SearchScope.countdowns)) {
      ref.invalidate(searchCountdownsProvider);
    }
    if (_show(scope, SearchScope.tags)) ref.invalidate(searchTagsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsById = ref.watch(taskListsByIdProvider);
    final calendars = ref.watch(calendarsProvider).value ?? const <Calendar>[];
    final calendarsById = {for (final c in calendars) c.id: c};

    final tasks = _show(scope, SearchScope.tasks)
        ? ref.watch(searchTasksProvider)
        : null;
    final events = _show(scope, SearchScope.events)
        ? ref.watch(searchEventsProvider)
        : null;
    final notes = _show(scope, SearchScope.notes)
        ? ref.watch(searchNotesProvider)
        : null;
    final habits = _show(scope, SearchScope.habits)
        ? ref.watch(searchHabitsProvider)
        : null;
    final countdowns = _show(scope, SearchScope.countdowns)
        ? ref.watch(searchCountdownsProvider)
        : null;
    final tags = _show(scope, SearchScope.tags)
        ? ref.watch(searchTagsProvider)
        : null;

    final states = <({bool loading, bool hasRows, bool hasError})>[
      if (tasks != null)
        (
          loading: tasks.isLoading,
          hasRows: tasks.hasValue && tasks.requireValue.isNotEmpty,
          hasError: tasks.hasError,
        ),
      if (events != null)
        (
          loading: events.isLoading,
          hasRows: events.hasValue && events.requireValue.isNotEmpty,
          hasError: events.hasError,
        ),
      if (notes != null)
        (
          loading: notes.isLoading,
          hasRows: notes.hasValue && notes.requireValue.isNotEmpty,
          hasError: notes.hasError,
        ),
      if (habits != null)
        (
          loading: habits.isLoading,
          hasRows: habits.hasValue && habits.requireValue.isNotEmpty,
          hasError: habits.hasError,
        ),
      if (countdowns != null)
        (
          loading: countdowns.isLoading,
          hasRows: countdowns.hasValue && countdowns.requireValue.isNotEmpty,
          hasError: countdowns.hasError,
        ),
      if (tags != null)
        (
          loading: tags.isLoading,
          hasRows: tags.hasValue && tags.requireValue.isNotEmpty,
          hasError: tags.hasError,
        ),
    ];
    final hasRows = states.any((state) => state.hasRows);
    final anyLoading = states.any((state) => state.loading);
    final anyError = states.any((state) => state.hasError);

    if (!hasRows && anyError) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Search failed',
        subtitle: 'Some results could not be loaded.',
        actionLabel: 'Retry',
        onAction: () => _retry(ref),
      );
    }
    if (!hasRows && anyLoading) return AppSkeleton.list(context);
    if (!hasRows) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No results',
        subtitle: 'Nothing matched "$query".',
        actionLabel: 'Clear search',
        onAction: () => onClear(),
      );
    }

    final items = <Widget>[];
    if (tasks != null) {
      items.add(
        _Group<Task>(
          title: l.searchTasks,
          async: tasks,
          onRetry: () => ref.invalidate(searchTasksProvider),
          tile: (t) {
            final list = t.listId == null ? null : listsById[t.listId];
            final source = sourceLabel(
              name: list?.name,
              account: accountForSource(
                googleAccount: t.googleAccount,
                microsoftAccount: t.microsoftAccount,
              ),
              fallbackAccount: accountForSource(
                googleAccount: list?.googleAccount,
                microsoftAccount: list?.microsoftAccount,
              ),
            );
            return ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: Text(t.title),
              subtitle: (source == null && t.dueDate == null)
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (source != null) Text(source),
                        if (t.dueDate != null)
                          Text(DeviceDateFormat.dateIso(context, t.dueDate!)),
                      ],
                    ),
              onTap: () => showTaskEditor(context, task: t),
            );
          },
        ),
      );
    }
    if (events != null) {
      items.add(
        _Group<Event>(
          title: l.searchEvents,
          async: events,
          onRetry: () => ref.invalidate(searchEventsProvider),
          tile: (e) {
            final calendar = calendarsById[e.calendarId];
            final source = sourceLabel(
              name: calendar?.name,
              account: accountForSource(
                googleAccount: e.googleAccount,
                microsoftAccount: e.microsoftAccount,
              ),
              fallbackAccount: accountForSource(
                googleAccount: calendar?.googleAccount,
                microsoftAccount: calendar?.microsoftAccount,
              ),
              isLocal:
                  calendar == null ||
                  (calendar.source != 'google' &&
                      calendar.source != 'microsoft'),
            );
            return ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(e.title.isEmpty ? '(no title)' : e.title),
              subtitle: (source == null && e.location == null)
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (source != null) Text(source),
                        if (e.location != null) Text(e.location!),
                      ],
                    ),
              onTap: () => showEventDetails(context, e.id),
            );
          },
        ),
      );
    }
    if (notes != null) {
      items.add(
        _Group<NoteSearchHit>(
          title: l.searchNotes,
          async: notes,
          onRetry: () => ref.invalidate(searchNotesProvider),
          tile: (h) => ListTile(
            leading: const Icon(Icons.note_outlined),
            title: Text(h.note.title.isEmpty ? '(no title)' : h.note.title),
            subtitle: _SnippetLine(snippet: h.snippet, query: query),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NoteEditorScreen(noteId: h.note.id),
              ),
            ),
          ),
        ),
      );
    }
    if (habits != null) {
      items.add(
        _Group<Habit>(
          title: l.searchHabits,
          async: habits,
          onRetry: () => ref.invalidate(searchHabitsProvider),
          tile: (h) => ListTile(
            leading: const Icon(Icons.repeat_outlined),
            title: Text(h.name),
            onTap: () => showHabitEditor(context, habit: h),
          ),
        ),
      );
    }
    if (countdowns != null) {
      items.add(
        _Group<Countdown>(
          title: l.searchCountdowns,
          async: countdowns,
          onRetry: () => ref.invalidate(searchCountdownsProvider),
          tile: (c) => ListTile(
            leading: const Icon(Icons.hourglass_bottom_outlined),
            title: Text(c.title),
            subtitle: c.targetDate == null
                ? null
                : Text(DeviceDateFormat.dateIso(context, c.targetDate!)),
            onTap: () => showCountdownEditor(context, countdown: c),
          ),
        ),
      );
    }
    if (tags != null) {
      items.add(
        _Group<Tag>(
          title: l.searchTags,
          async: tags,
          onRetry: () => ref.invalidate(searchTagsProvider),
          tile: (t) => ListTile(
            leading: const Icon(Icons.tag),
            title: Text(t.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showAppSheet<void>(
              context,
              builder: (_) => EscapeToClose(child: _TagTasksSheet(tag: t)),
            ),
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}
