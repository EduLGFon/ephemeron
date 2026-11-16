// Habit statistics screen: weighted goal compliance, streaks, day counts,
// remaining deficit, weekly progress, and catch-up actions.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../core/time/device_date_format.dart';
import '../../../core/ui/empty_state.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/habits/date_key.dart';
import '../../../domain/habits/habit_stats.dart';
import '../../../domain/habits/habit_timer.dart';
import '../application/habits_providers.dart';

class HabitsStatsScreen extends ConsumerWidget {
  const HabitsStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(showArchivedHabitsProvider);
    final habitsAsync = ref.watch(habitsProvider(archived));

    return Scaffold(
      appBar: AppBar(title: const Text('Habit statistics')),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(habitsProvider(archived)),
            child: const Text('Retry'),
          ),
        ),
        data: (habits) {
          if (habits.isEmpty) {
            return const EmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'No habits yet.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpace.md),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return _HabitStatsCard(habit: habit);
            },
          );
        },
      ),
    );
  }
}

class _HabitStatsCard extends ConsumerWidget {
  const _HabitStatsCard({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(habitStatsProvider(habit.id));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: statsAsync.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(habit.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpace.sm),
              const LinearProgressIndicator(),
            ],
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(habit.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Could not load stats.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          data: (stats) {
            if (stats == null) {
              return Text(habit.name, style: theme.textTheme.titleMedium);
            }
            return _buildStats(context, ref, stats);
          },
        ),
      ),
    );
  }

  Widget _buildStats(
    BuildContext context,
    WidgetRef ref,
    HabitStatsSummary stats,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final children = <Widget>[];

    children.add(Text(habit.name, style: theme.textTheme.titleMedium));
    if (habit.unit != null || habit.frequency != 'daily') {
      children.add(
        Text(
          _frequencyLabel(habit),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    children.add(const SizedBox(height: AppSpace.sm));

    // Compliance headline (last 7 days) plus secondary 30-day figure.
    // Stacked so it never overflows at narrow widths / large text scales.
    children.add(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatCompliancePercent(stats.compliance7),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          Text(
            'last 7 days',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            '30 days: ${formatCompliancePercent(stats.compliance30)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    children.add(const SizedBox(height: AppSpace.xs));
    children.add(
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: LinearProgressIndicator(
          value: stats.compliance30,
          minHeight: 6,
          color: scheme.primary,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
    );
    children.add(const SizedBox(height: AppSpace.sm));

    // Stat chips.
    final chips = <Widget>[
      _StatChip('Streak', '${stats.currentStreak}'),
      _StatChip('Best', '${stats.bestStreak}'),
      _StatChip('Perfect', '${stats.perfectDays}'),
      _StatChip('Partial', '${stats.partialDays}'),
      _StatChip('Missed', '${stats.missedDays}'),
      _StatChip('Skipped', '${stats.skippedDays}'),
    ];
    children.add(
      Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: chips),
    );
    children.add(const SizedBox(height: AppSpace.sm));

    // Totals line.
    if (stats.hasGoal) {
      children.add(
        Text(
          'Logged ${formatHabitAmount(unit: habit.unit, amount: stats.totalLogged)} '
          'of ${formatHabitAmount(unit: habit.unit, amount: stats.totalGoal)}',
          style: theme.textTheme.bodySmall,
        ),
      );
    } else {
      children.add(
        Text(
          'Done ${stats.perfectDays} of ${stats.scoredDays} scheduled days',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (stats.hasGoal && stats.deficit > 0) {
      children.add(
        Text(
          '${formatHabitAmount(unit: habit.unit, amount: stats.deficit)} left to 100%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    children.add(const SizedBox(height: AppSpace.sm));

    // Weekly target progress.
    final weekly = stats.weekly;
    if (weekly != null) {
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week: ${weekly.done}/${weekly.target}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpace.xxs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: weekly.ratio,
                minHeight: 4,
                color: scheme.secondary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      );
    }

    // Catch-up actions for recent partial days.
    if (stats.catchUpDays.isNotEmpty) {
      children.add(
        Text(
          'Catch up',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      children.add(const SizedBox(height: AppSpace.xxs));
      for (final day in stats.catchUpDays) {
        final missing = formatHabitAmount(
          unit: habit.unit,
          amount: day.missing,
        );
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_dayLabel(context, day.dayKey)}: '
                  '${formatHabitProgress(unit: habit.unit, amount: day.amount, goal: day.goal)}',
                  style: theme.textTheme.bodySmall,
                ),
                _CatchUpButton(
                  habitId: habit.id,
                  dayKey: day.dayKey,
                  amount: day.missing,
                  label: 'Add $missing',
                ),
              ],
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  String _frequencyLabel(Habit habit) {
    switch (habit.frequency) {
      case 'weekly':
        return 'Weekly target ${habit.weeklyTarget ?? 0}';
      case 'weekdays':
        return 'Weekdays';
      case 'interval':
        return 'Every ${habit.intervalDays ?? 1} days';
      default:
        return 'Daily';
    }
  }

  String _dayLabel(BuildContext context, String dayKey) {
    final today = habitDateKey(DateTime.now());
    if (dayKey == today) return 'Today';
    final y = habitDateKey(DateTime.now().subtract(const Duration(days: 1)));
    if (dayKey == y) return 'Yesterday';
    return DeviceDateFormat.shortDate(context, parseKey(dayKey));
  }
}

class _CatchUpButton extends ConsumerStatefulWidget {
  const _CatchUpButton({
    required this.habitId,
    required this.dayKey,
    required this.amount,
    required this.label,
  });

  final String habitId;
  final String dayKey;
  final double amount;
  final String label;

  @override
  ConsumerState<_CatchUpButton> createState() => _CatchUpButtonState();
}

class _CatchUpButtonState extends ConsumerState<_CatchUpButton> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    var success = false;
    try {
      await ref
          .read(habitRepositoryProvider)
          .addAmount(widget.habitId, widget.dayKey, widget.amount);
      success = true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this day. Try again.'),
          ),
        );
      }
    }
    if (success && mounted) {
      ref.invalidate(habitStatsProvider(widget.habitId));
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _busy ? null : _handleTap,
      icon: const Icon(Icons.add, size: 16),
      label: Text(widget.label),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$label $value',
        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurface),
      ),
    );
  }
}
