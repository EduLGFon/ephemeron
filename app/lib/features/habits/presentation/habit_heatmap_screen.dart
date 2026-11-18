// Habit activity: a compact 16-week heatmap for one habit or every active
// habit. Values use the same done/goal rule as the list rows.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/app_buttons.dart';
import '../../../core/design/components/app_headers.dart';
import '../../../core/design/components/app_page.dart';
import '../../../core/design/components/app_states.dart';
import '../../../core/design/components/app_surface.dart';
import '../../../core/design/components/visuals.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/habits/date_key.dart';
import '../application/habits_providers.dart';
import 'habits_strings.dart';

/// Builds the Monday-first value grid AppHeatmap expects. Keys are day keys.
List<num> habitHeatmapValues({
  required DateTime today,
  required Map<String, num> byDay,
  int weeks = 16,
}) {
  final safeWeeks = weeks < 1 ? 1 : weeks;
  final day = DateTime(today.year, today.month, today.day);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  final first = monday.subtract(Duration(days: (safeWeeks - 1) * 7));
  return [
    for (var i = 0; i < safeWeeks * 7; i++)
      byDay[habitDateKey(first.add(Duration(days: i)))] ?? 0,
  ];
}

Map<String, num> _heatValues(Habit habit, List<HabitLog> logs) {
  final out = <String, num>{};
  final goal = habit.goalAmount ?? 0;
  for (final log in logs) {
    final done = log.done || (goal > 0 && log.amount >= goal);
    if (log.skipped && !done) continue;
    out[log.dayKey] = done ? (goal > 0 ? goal : 1) : log.amount;
  }
  return out;
}

class HabitHeatmapScreen extends ConsumerWidget {
  const HabitHeatmapScreen({super.key, this.habitId});

  final String? habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = HabitsStrings.of(context);
    final habitsAsync = ref.watch(habitsProvider(false));
    return AppPage(
      header: AppPageHeader(
        leading: AppIconButton(
          icon: Icons.arrow_back,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(strings.heatmapTitle),
        subtitle: Text(strings.heatmapSubtitle),
      ),
      child: habitsAsync.when(
        loading: () => const AppSkeletonList(rows: 3),
        error: (_, _) => AppErrorState(
          title: strings.loadError,
          onRetry: () => ref.invalidate(habitsProvider(false)),
        ),
        data: (all) {
          final habits = habitId == null
              ? all
              : all.where((h) => h.id == habitId).toList();
          if (habits.isEmpty) {
            return AppEmptyState(
              icon: Icons.grid_on_outlined,
              title: strings.heatmapEmpty,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: DsSpace.x48),
            itemCount: habits.length,
            separatorBuilder: (_, _) => const SizedBox(height: DsSpace.x12),
            itemBuilder: (context, index) => _HabitHeatmapCard(
              key: ValueKey(habits[index].id),
              habit: habits[index],
              strings: strings,
            ),
          );
        },
      ),
    );
  }
}

class _HabitHeatmapCard extends ConsumerWidget {
  const _HabitHeatmapCard({
    super.key,
    required this.habit,
    required this.strings,
  });

  final Habit habit;
  final HabitsStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(habitLogsProvider(habit.id));
    final streakAsync = ref.watch(habitStreakProvider(habit.id));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = streakAsync.value?.current ?? 0;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (current > 0)
                Text(
                  strings.streak(current),
                  style: DsType.numeric(
                    theme.textTheme.labelSmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DsSpace.x12),
          logsAsync.maybeWhen(
            data: (logs) => AppHeatmap(
              values: habitHeatmapValues(
                today: DateTime.now(),
                byDay: _heatValues(habit, logs),
              ),
              color: scheme.primary,
              semanticsLabel: strings.heatmapSemantics(habit.name),
            ),
            orElse: () => const AppSkeleton(height: 120),
          ),
        ],
      ),
    );
  }
}
