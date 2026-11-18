// Part of the habits screen library: default and selection headers.
part of '../habits_screen.dart';

extension _HabitsHeaders on _HabitsScreenState {
  Widget _defaultHeader(HabitsStrings strings, bool archived, int habitCount) {
    return AppPageHeader(
      title: Text(strings.title),
      subtitle: habitCount == 0 ? null : Text(strings.habitCount(habitCount)),
      actions: [
        AppIconButton(
          icon: Icons.bar_chart_outlined,
          tooltip: strings.statisticsTooltip,
          semanticLabel: strings.statisticsTooltip,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const HabitsStatsScreen()),
          ),
        ),
        AppIconButton(
          icon: Icons.grid_on_outlined,
          tooltip: strings.heatmapTooltip,
          semanticLabel: strings.heatmapTooltip,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const HabitHeatmapScreen()),
          ),
        ),
        AppIconButton(
          icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          tooltip: archived
              ? strings.hideArchivedTooltip
              : strings.showArchivedTooltip,
          semanticLabel: archived
              ? strings.hideArchivedTooltip
              : strings.showArchivedTooltip,
          selected: archived,
          onPressed: () =>
              ref.read(showArchivedHabitsProvider.notifier).toggle(),
        ),
      ],
    );
  }

  Widget _selectionHeader(HabitsStrings strings, List<Habit> selectedHabits) {
    final allArchived =
        selectedHabits.isNotEmpty && selectedHabits.every((h) => h.archived);
    return AppPageHeader(
      leading: AppIconButton(
        icon: Icons.close,
        tooltip: strings.clearSelectionTooltip,
        semanticLabel: strings.clearSelectionTooltip,
        onPressed: _clearSelection,
      ),
      title: Text(strings.selected(_selected.length)),
      actions: [
        AppIconButton(
          icon: allArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
          tooltip: allArchived ? strings.unarchive : strings.archive,
          semanticLabel: allArchived ? strings.unarchive : strings.archive,
          onPressed: selectedHabits.isEmpty ? null : _archiveSelected,
        ),
        AppIconButton(
          icon: Icons.delete_outline,
          tooltip: strings.delete,
          semanticLabel: strings.delete,
          onPressed: selectedHabits.isEmpty ? null : _deleteSelected,
        ),
      ],
    );
  }
}
