// Habits screen: day navigation, sectioned list, one-tap logging, skip,
// streaks and a compact week of dots. Long-press starts multi-select with
// archive/delete and the standard six-second undo window. The screen is one
// library split into part files so each widget stays small.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/app_buttons.dart';
import '../../../core/design/components/app_chips.dart';
import '../../../core/design/components/app_headers.dart';
import '../../../core/design/components/app_overlays.dart';
import '../../../core/design/components/app_page.dart';
import '../../../core/design/components/app_states.dart';
import '../../../core/design/components/rows.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/time/device_date_format.dart';
import '../../../core/ui/app_feedback.dart';
import '../../../core/ui/app_motion.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/repositories/habit_repository.dart';
import '../../../data/services/habit_timer_store.dart';
import '../../../domain/habits/date_key.dart';
import '../../../domain/habits/habit_timer.dart';
import '../../focus/application/focus_providers.dart';
import '../../sync/application/pending_operations.dart';
import '../application/habits_providers.dart';
import 'habit_editor_sheet.dart';
import 'habit_heatmap_screen.dart';
import 'habits_stats_screen.dart';
import 'habits_strings.dart';

part 'habits_screen/day_strip.dart';
part 'habits_screen/header.dart';
part 'habits_screen/habit_list.dart';
part 'habits_screen/habit_tile.dart';
part 'habits_screen/habit_tile_status.dart';
part 'habits_screen/habit_timer_control.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  // Selection is local to the screen. The header and list both read it, and
  // the list is small enough that one owning set stays simple.
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
  List<Habit> _liveSelectedHabits() {
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

  Future<void> _archiveSelected() async {
    final strings = HabitsStrings.of(context);
    final selected = _liveSelectedHabits();
    if (selected.isEmpty) {
      _clearSelection();
      return;
    }
    final unifyArchive = !selected.every((h) => h.archived);
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
    showUndoSnackBar(
      context,
      unifyArchive
          ? strings.archivedMessage(targets.length)
          : strings.unarchivedMessage(targets.length),
      onUndo: () => pending.cancelAll(opIds),
    );
  }

  Future<void> _deleteSelected() async {
    final strings = HabitsStrings.of(context);
    final selected = _liveSelectedHabits();
    if (selected.isEmpty) {
      _clearSelection();
      return;
    }
    final count = selected.length;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteDialogTitle(count)),
        content: Text(strings.deleteDialogBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Re-resolve after the dialog: the active list may have changed while it
    // was open.
    final targets = _liveSelectedHabits();
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
    showUndoSnackBar(
      context,
      strings.deletedMessage(targets.length),
      onUndo: () => pending.cancelAll(opIds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = HabitsStrings.of(context);
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
    final liveIds = habits.map((h) => h.id).toSet();
    if (_selected.isNotEmpty && !_selected.every(liveIds.contains)) {
      _selected.removeWhere((id) => !liveIds.contains(id));
    }
    final selectedHabits = habits
        .where((h) => _selected.contains(h.id))
        .toList();
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _clearSelection();
      },
      child: AppPage(
        header: _selecting
            ? _selectionHeader(strings, selectedHabits)
            : _defaultHeader(strings, archived, habits.length),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DayStrip(
              selected: selectedDay,
              strings: strings,
              onSelect: (d) =>
                  ref.read(selectedHabitDayProvider.notifier).select(d),
            ),
            const SizedBox(height: DsSpace.x8),
            Expanded(
              child: habitsAsync.when(
                loading: () => const AppSkeletonList(rows: 6),
                error: (_, _) => AppErrorState(
                  title: strings.loadError,
                  onRetry: () => ref.invalidate(habitsProvider(archived)),
                ),
                data: (habits) {
                  if (habits.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.repeat_outlined,
                      title: archived
                          ? strings.emptyArchivedTitle
                          : strings.emptyTitle,
                      message: archived
                          ? strings.emptyArchivedMessage
                          : strings.emptyMessage,
                      actionLabel: archived ? null : strings.addHabit,
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
                      strings: strings,
                      onToggleSelection: _toggleSelection,
                      onStartSelection: _startSelection,
                    ),
                    orElse: () => _HabitList(
                      habits: habits,
                      sections: const [],
                      selecting: _selecting,
                      selectedIds: _selected,
                      strings: strings,
                      onToggleSelection: _toggleSelection,
                      onStartSelection: _startSelection,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
