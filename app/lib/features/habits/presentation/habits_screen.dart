// Habits screen: 7-day navigator, sections, one-tap logging,
// skip, streaks, selection with archive/delete undo.
//
// The screen is a single Dart library split into `part` files under
// presentation/habits_screen/ so each widget stays focused while private
// members remain shared within the screen. The entry point and import
// path are unchanged for existing importers.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ephemeron/core/theme/theme_tokens.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/core/ui/app_motion.dart';
import 'package:ephemeron/core/ui/empty_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/habits/date_key.dart';
import '../../../domain/habits/habit_timer.dart';
import '../../focus/application/focus_providers.dart';
import '../../sync/application/pending_operations.dart';
import '../application/habits_providers.dart';
import '../../../data/repositories/habit_repository.dart';
import '../../../data/services/habit_timer_store.dart';
import 'habit_editor_sheet.dart';

part 'habits_screen/day_strip.dart';
part 'habits_screen/habit_list.dart';
part 'habits_screen/habit_tile.dart';
part 'habits_screen/habit_timer_control.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  // Selection is local to the screen. The list is small and the app bar,
  // list, and floating button all read it, so a single widget-owned set keeps
  // the selection mode in sync without a new provider.
  final Set<String> _selected = <String>{};

  bool get _selecting => _selected.isNotEmpty;

  void _clearSelection() {
    if (_selected.isEmpty) return;
    setState(_selected.clear);
  }

  void _startSelection(String id) {
    setState(() => _selected.add(id));
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  /// Current selected rows from the latest active-list snapshot. Bulk actions
  /// resolve this at action time so a stale build snapshot can never be
  /// scheduled.
  List<Habit> _liveSelectedHabits(WidgetRef ref) {
    final archived = ref.read(showArchivedHabitsProvider);
    final habits = ref
        .read(habitsProvider(archived))
        .maybeWhen(data: (value) => value, orElse: () => const <Habit>[]);
    return habits.where((h) => _selected.contains(h.id)).toList();
  }

  void _pruneSelection() {
    final archived = ref.read(showArchivedHabitsProvider);
    final habits = ref
        .read(habitsProvider(archived))
        .maybeWhen(data: (value) => value, orElse: () => null);
    if (habits == null) return;
    final liveIds = habits.map((h) => h.id).toSet();
    final stale = _selected.where((id) => !liveIds.contains(id)).toList();
    if (stale.isEmpty) return;
    setState(() => _selected.removeAll(stale));
  }

  Future<void> _archiveSelected(WidgetRef ref) async {
    final selected = _liveSelectedHabits(ref);
    if (selected.isEmpty) {
      _clearSelection();
      return;
    }
    final unifyArchive = !selected.every((h) => h.archived);
    // Mixed selections skip rows that already match the target state.
    final targets = selected.where((h) => h.archived != unifyArchive).toList();
    if (targets.isEmpty) {
      _clearSelection();
      return;
    }
    final pending = ref.read(pendingOperationsProvider);
    final opIds = <String>[];
    for (final habit in targets) {
      opIds.add(await pending.scheduleHabitArchive(habit.id, unifyArchive));
    }
    if (!mounted) return;
    _clearSelection();
    final action = unifyArchive ? 'archived' : 'unarchived';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          targets.length == 1 ? 'Habit $action.' : 'Habits $action.',
        ),
        duration: const Duration(seconds: 6),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => pending.cancelAll(opIds),
        ),
      ),
    );
  }

  Future<void> _deleteSelected(WidgetRef ref) async {
    final selected = _liveSelectedHabits(ref);
    if (selected.isEmpty) {
      _clearSelection();
      return;
    }
    final count = selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(count == 1 ? 'Delete 1 habit?' : 'Delete $count habits?'),
        content: Text(
          count == 1
              ? 'This habit will be deleted.'
              : 'These $count habits will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Re-resolve after the dialog: the active list may have changed while it
    // was open.
    final targets = _liveSelectedHabits(ref);
    if (targets.isEmpty) {
      _clearSelection();
      return;
    }
    final pending = ref.read(pendingOperationsProvider);
    final opIds = <String>[];
    for (final habit in targets) {
      opIds.add(await pending.scheduleHabitDelete(habit.id));
    }
    if (!mounted) return;
    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          targets.length == 1 ? 'Habit deleted.' : 'Habits deleted.',
        ),
        duration: const Duration(seconds: 6),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => pending.cancelAll(opIds),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final archived = ref.watch(showArchivedHabitsProvider);
    final habitsAsync = ref.watch(habitsProvider(archived));
    final sectionsAsync = ref.watch(habitSectionsProvider);
    final selectedDay = ref.watch(selectedHabitDayProvider);
    // Selection must never outlive the rows it points at. The listener prunes
    // after the frame so setState never runs during build.
    ref.listen<AsyncValue<List<Habit>>>(habitsProvider(archived), (_, next) {
      final ids = next.maybeWhen(
        data: (habits) => habits.map((h) => h.id).toSet(),
        orElse: () => null,
      );
      if (ids == null || _selected.every(ids.contains)) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pruneSelection();
      });
    });
    final habits = habitsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <Habit>[],
    );
    final selectedHabits = habits
        .where((h) => _selected.contains(h.id))
        .toList();
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _clearSelection();
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionAppBar(ref, selectedHabits)
            : _defaultAppBar(ref, archived),
        body: Column(
          children: [
            _DayStrip(
              selected: selectedDay,
              onSelect: (d) =>
                  ref.read(selectedHabitDayProvider.notifier).select(d),
            ),
            Expanded(
              child: habitsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _ErrorState(
                  onRetry: () => ref.invalidate(habitsProvider(archived)),
                ),
                data: (habits) {
                  if (habits.isEmpty) {
                    return EmptyState(
                      icon: Icons.repeat_outlined,
                      title: archived
                          ? 'No archived habits.'
                          : 'No habits yet.',
                      actionLabel: archived ? null : 'Add habit',
                      onAction: archived
                          ? null
                          : () => showHabitEditor(context),
                    );
                  }
                  return sectionsAsync.maybeWhen(
                    data: (sections) => _HabitList(
                      habits: habits,
                      sections: sections,
                      selecting: _selecting,
                      selectedIds: _selected,
                      onToggleSelection: _toggleSelection,
                      onStartSelection: _startSelection,
                    ),
                    orElse: () => _HabitList(
                      habits: habits,
                      sections: const [],
                      selecting: _selecting,
                      selectedIds: _selected,
                      onToggleSelection: _toggleSelection,
                      onStartSelection: _startSelection,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton(
                heroTag: 'habitsFab',
                onPressed: () => showHabitEditor(context),
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  AppBar _defaultAppBar(WidgetRef ref, bool archived) {
    return AppBar(
      title: const Text('Habits'),
      actions: [
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          icon: Icon(
            archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          ),
          tooltip: archived ? 'Hide archived' : 'Show archived',
          onPressed: () =>
              ref.read(showArchivedHabitsProvider.notifier).toggle(),
        ),
      ],
    );
  }

  AppBar _selectionAppBar(WidgetRef ref, List<Habit> selectedHabits) {
    final allArchived =
        selectedHabits.isNotEmpty && selectedHabits.every((h) => h.archived);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Clear selection',
        onPressed: _clearSelection,
      ),
      title: Text('${selectedHabits.length} selected'),
      actions: [
        IconButton(
          icon: Icon(
            allArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
          ),
          tooltip: allArchived ? 'Unarchive' : 'Archive',
          onPressed: selectedHabits.isEmpty
              ? null
              : () => _archiveSelected(ref),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: selectedHabits.isEmpty ? null : () => _deleteSelected(ref),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load habits.'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
