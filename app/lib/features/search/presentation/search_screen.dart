// Global search screen: one field across tasks, events, notes,
// habits, countdowns and tags, with type filters. Results open the matching
// editor or detail sheet so search is a navigation surface, not a dead end.
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:ephemeron/core/design/components/app_chips.dart';
import 'package:ephemeron/core/design/components/app_fields.dart';
import 'package:ephemeron/core/design/components/app_headers.dart';
import 'package:ephemeron/core/design/components/app_page.dart';
import 'package:ephemeron/core/design/components/app_states.dart';
import 'package:ephemeron/core/design/components/app_surface.dart';
import 'package:ephemeron/core/design/components/app_buttons.dart';
import 'package:ephemeron/core/design/components/app_overlays.dart';
import 'package:ephemeron/core/design/tokens.dart';
import 'package:ephemeron/core/search/limits.dart';
import 'package:ephemeron/core/search/sanitize.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/core/ui/app_sheet.dart';
import 'package:ephemeron/core/ui/escape_to_close.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ephemeron/data/drift/app_database.dart';
import 'package:ephemeron/data/repositories/note_repository.dart';
import 'package:ephemeron/domain/sources/source_label.dart';
import 'package:ephemeron/features/calendar/application/calendar_providers.dart';
import 'package:ephemeron/features/calendar/presentation/event_details_sheet.dart';
import 'package:ephemeron/features/countdowns/presentation/countdown_editor_sheet.dart';
import 'package:ephemeron/features/habits/presentation/habit_editor_sheet.dart';
import 'package:ephemeron/features/notes/presentation/note_editor_screen.dart';
import 'package:ephemeron/features/settings/application/settings_providers.dart';
import 'package:ephemeron/features/tasks/application/tasks_providers.dart';
import 'package:ephemeron/features/tasks/presentation/task_editor_sheet.dart';

import '../application/search_providers.dart';
import 'search_strings.dart';

part 'search_screen/results.dart';
part 'search_screen/results/group.dart';
part 'search_screen/results/result_row.dart';
part 'search_screen/results/snippet.dart';
part 'search_screen/results/tag_tasks_sheet.dart';

Map<SearchScope, String> _scopeLabels(AppLocalizations l) => {
  SearchScope.all: l.searchAll,
  SearchScope.tasks: l.searchTasks,
  SearchScope.events: l.searchEvents,
  SearchScope.notes: l.searchNotes,
  SearchScope.habits: l.searchHabits,
  SearchScope.countdowns: l.searchCountdowns,
  SearchScope.tags: l.searchTags,
};

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      _restored = true;
      Future.microtask(() async {
        try {
          final repo = await ref.read(settingsRepositoryProvider.future);
          final q = repo.searchQuery;
          final scopeName = repo.searchScope;
          if (!mounted) return;
          if (q.isNotEmpty) {
            _controller.text = q;
            ref.read(searchQueryProvider.notifier).set(q);
          }
          final scope = SearchScope.values.firstWhere(
            (s) => s.name == scopeName,
            orElse: () => SearchScope.all,
          );
          ref.read(searchScopeProvider.notifier).set(scope);
          // Track the route so restarts return here.
          await repo.setLastRoute('/search');
        } catch (_) {}
      });
    }
  }

  Future<void> _onQueryChanged(String v) async {
    ref.read(searchQueryProvider.notifier).set(v);
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.setSearchQuery(v);
    } catch (_) {}
  }

  Future<void> _onScopeChanged(SearchScope s) async {
    if (ref.read(searchScopeProvider) == s) return;
    AppFeedback.tap();
    ref.read(searchScopeProvider.notifier).set(s);
    try {
      final repo = await ref.read(settingsRepositoryProvider.future);
      await repo.setSearchScope(s.name);
    } catch (_) {}
  }

  Future<void> _clearQuery() async {
    if (_controller.text.isEmpty) return;
    _controller.clear();
    await _onQueryChanged('');
  }

  void _onExample(String example) {
    _controller.value = TextEditingValue(
      text: example,
      selection: TextSelection.collapsed(offset: example.length),
    );
    _onQueryChanged(example);
  }

  void _handleEscape() {
    if (_controller.text.isNotEmpty) {
      _clearQuery();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(searchScopeProvider);
    final query = ref.watch(searchQueryProvider);
    final l = AppLocalizations.of(context);
    final strings = SearchStrings.of(context);
    final trimmed = query.trim();
    final canPop = Navigator.of(context).canPop();
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false):
            DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _handleEscape();
              return null;
            },
          ),
        },
        child: AppPage(
          padding: const EdgeInsets.fromLTRB(DsSpace.x16, 0, DsSpace.x16, 0),
          header: AppPageHeader(
            title: Text(
              l.searchTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: canPop
                ? AppIconButton(
                    icon: Icons.arrow_back,
                    tooltip: strings.back,
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: DsSpace.x8),
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      _handleEscape();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: AppSearchField(
                    key: const Key('search-field'),
                    controller: _controller,
                    hintText: l.searchHint,
                    autofocus: true,
                    onChanged: _onQueryChanged,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: DsSpace.x8),
                child: Row(
                  children: [
                    for (final s in SearchScope.values) ...[
                      AppFilterChip(
                        label: _scopeLabels(l)[s] ?? s.name,
                        selected: scope == s,
                        onSelected: (_) => _onScopeChanged(s),
                      ),
                      const SizedBox(width: DsSpace.x8),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: trimmed.isEmpty
                    ? _SearchHint(l: l, strings: strings, onExample: _onExample)
                    : _Results(
                        scope: scope,
                        l: l,
                        strings: strings,
                        query: trimmed,
                        onClear: _clearQuery,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({
    required this.l,
    required this.strings,
    required this.onExample,
  });

  final AppLocalizations l;
  final SearchStrings strings;
  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.x16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppEmptyState(
            icon: Icons.manage_search,
            title: l.searchEmpty,
            message: strings.examplesIntro,
          ),
          const SizedBox(height: DsSpace.x12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: DsSpace.x8,
            runSpacing: DsSpace.x8,
            children: [
              for (final example in strings.examples)
                AppChip(label: example, onTap: () => onExample(example)),
            ],
          ),
        ],
      ),
    );
  }
}
