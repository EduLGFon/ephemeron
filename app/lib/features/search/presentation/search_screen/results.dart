part of '../search_screen.dart';

bool _show(SearchScope scope, SearchScope s) =>
    scope == SearchScope.all || scope == s;

class _Results extends ConsumerWidget {
  const _Results({
    required this.scope,
    required this.l,
    required this.strings,
    required this.query,
    required this.onClear,
  });

  final SearchScope scope;
  final AppLocalizations l;
  final SearchStrings strings;
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
      return SingleChildScrollView(
        child: AppEmptyState(
          icon: Icons.error_outline,
          title: strings.searchFailedTitle,
          message: strings.searchFailedMessage,
          actionLabel: strings.retry,
          onAction: () => _retry(ref),
        ),
      );
    }
    if (!hasRows && anyLoading) {
      return const SingleChildScrollView(child: AppSkeletonList(rows: 5));
    }
    if (!hasRows) {
      return SingleChildScrollView(
        child: AppEmptyState(
          icon: Icons.search_off,
          title: strings.noResults,
          message: strings.nothingMatched(query),
          actionLabel: strings.clearSearch,
          onAction: () => onClear(),
        ),
      );
    }

    final items = <Widget>[];
    if (tasks != null) {
      items.add(
        _Group<Task>(
          title: l.searchTasks,
          async: tasks,
          strings: strings,
          onRetry: () => ref.invalidate(searchTasksProvider),
          row: (t) {
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
            final meta = <String>[
              ?source,
              if (t.dueDate != null)
                DeviceDateFormat.dateIso(context, t.dueDate!),
            ].join(' · ');
            return _ResultRow(
              icon: Icons.checklist_outlined,
              title: t.title,
              subtitle: meta.isEmpty ? null : Text(meta),
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
          strings: strings,
          onRetry: () => ref.invalidate(searchEventsProvider),
          row: (e) {
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
            final meta = <String>[?source, ?e.location].join(' · ');
            return _ResultRow(
              icon: Icons.calendar_month_outlined,
              title: e.title.isEmpty ? strings.noTitle : e.title,
              subtitle: meta.isEmpty ? null : Text(meta),
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
          strings: strings,
          onRetry: () => ref.invalidate(searchNotesProvider),
          row: (h) => _ResultRow(
            icon: Icons.note_outlined,
            title: h.note.title.isEmpty ? strings.noTitle : h.note.title,
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
          strings: strings,
          onRetry: () => ref.invalidate(searchHabitsProvider),
          row: (h) => _ResultRow(
            icon: Icons.repeat_outlined,
            title: h.name,
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
          strings: strings,
          onRetry: () => ref.invalidate(searchCountdownsProvider),
          row: (c) => _ResultRow(
            icon: Icons.hourglass_bottom_outlined,
            title: c.title,
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
          strings: strings,
          onRetry: () => ref.invalidate(searchTagsProvider),
          row: (t) => _ResultRow(
            icon: Icons.tag,
            title: t.name,
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
        padding: const EdgeInsets.only(bottom: DsSpace.x24),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}
