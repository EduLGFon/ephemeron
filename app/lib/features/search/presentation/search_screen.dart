// Global search screen: one field across tasks, events, notes,
// habits, countdowns and tags, with type filters. Results open the matching
// editor or detail sheet so search is a navigation surface, not a dead end.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ephemeron/core/search/limits.dart';
import 'package:ephemeron/core/search/sanitize.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/core/ui/app_sheet.dart';
import 'package:ephemeron/core/ui/app_skeleton.dart';
import 'package:ephemeron/core/ui/empty_state.dart';
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

part 'search_screen/results.dart';

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
  final _focusNode = FocusNode();
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _onSearchKeyEvent;
  }

  KeyEventResult _onSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _handleEscape();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

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
    _focusNode.requestFocus();
    await _onQueryChanged('');
  }

  void _onExample(String example) {
    _controller.value = TextEditingValue(
      text: example,
      selection: TextSelection.collapsed(offset: example.length),
    );
    _focusNode.requestFocus();
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
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(searchScopeProvider);
    final query = ref.watch(searchQueryProvider);
    final l = AppLocalizations.of(context);
    final trimmed = query.trim();
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
        child: Scaffold(
          appBar: AppBar(title: Text(l.searchTitle)),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  key: const Key('search-field'),
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: l.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: trimmed.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('search-clear'),
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close),
                            onPressed: _clearQuery,
                          ),
                  ),
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onQueryChanged,
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    for (final s in SearchScope.values) ...[
                      ChoiceChip(
                        label: Text(_scopeLabels(l)[s]!),
                        selected: scope == s,
                        onSelected: (_) => _onScopeChanged(s),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: trimmed.isEmpty
                    ? _SearchHint(l: l, onExample: _onExample)
                    : _Results(
                        scope: scope,
                        l: l,
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
  const _SearchHint({required this.l, required this.onExample});

  static const _examples = ['milk', 'meeting', 'gym'];

  final AppLocalizations l;
  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              l.searchEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try one of these searches:',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final example in _examples)
                  ActionChip(
                    label: Text(example),
                    onPressed: () => onExample(example),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
