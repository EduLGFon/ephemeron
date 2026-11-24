// Today habits strip. A chip tap advances one step toward the goal; only the
// leading circle marks the day fully done. The entry stream is the optimistic
// source of truth, so no local copy is kept.
import 'package:material_ui/material_ui.dart';

import '../../../../core/design/components/app_headers.dart';
import '../../../../core/design/components/rows.dart';
import '../../../../core/design/tokens.dart';
import '../../../../domain/habits/habit_calendar_entry.dart';
import '../today_strings.dart';

class TodayHabits extends StatelessWidget {
  const TodayHabits({
    super.key,
    required this.entries,
    required this.expanded,
    required this.onAdvance,
    required this.onDone,
  });

  final List<HabitCalendarEntry> entries;
  final bool expanded;

  /// Chip body tap: one step toward the goal. The repository turns this into a
  /// done flip for goal-less habits.
  final ValueChanged<HabitCalendarEntry> onAdvance;

  /// Leading circle tap: mark the day fully done.
  final ValueChanged<HabitCalendarEntry> onDone;

  @override
  Widget build(BuildContext context) {
    final strings = TodayStrings.of(context);
    final theme = Theme.of(context);
    if (entries.isEmpty) return const SizedBox.shrink();
    final chips = <Widget>[
      for (var i = 0; i < entries.length; i++)
        _TodayHabitChip(
          entry: entries[i],
          progress: _progress(entries[i]),
          color: DsCategoryColors.forIndex(i).fill(theme.brightness),
          onAdvance: () => onAdvance(entries[i]),
          onDone: () => onDone(entries[i]),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionTitle(title: strings.habitsTitle, count: entries.length),
        if (expanded)
          Wrap(spacing: DsSpace.x8, runSpacing: DsSpace.x8, children: chips)
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: DsSpace.x8),
              itemBuilder: (context, index) => chips[index],
            ),
          ),
      ],
    );
  }

  double _progress(HabitCalendarEntry entry) {
    if (entry.hasGoal) {
      return (entry.amount / entry.goalAmount!).clamp(0.0, 1.0);
    }
    return entry.done ? 1.0 : 0.0;
  }
}

class _TodayHabitChip extends StatelessWidget {
  const _TodayHabitChip({
    required this.entry,
    required this.progress,
    required this.color,
    required this.onAdvance,
    required this.onDone,
  });

  final HabitCalendarEntry entry;
  final double progress;
  final Color color;
  final VoidCallback onAdvance;
  final VoidCallback onDone;

  // AppHabitChip pads 8dp and draws a 56dp ring. A 40dp target centred on the
  // ring starts at 8 + (56 - 40) / 2 = 16dp from the chip's top edge, matching
  // the habits screen's leading done target.
  static const double _ringSize = 56;
  static const double _doneTargetSize = 40;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppHabitChip(
          key: ValueKey<String>('today-habit-${entry.habitId}'),
          name: entry.habitName,
          progress: progress,
          done: entry.done,
          color: color,
          onTap: onAdvance,
        ),
        Positioned(
          left: 0,
          right: 0,
          top: DsSpace.x8 + (_ringSize - _doneTargetSize) / 2,
          height: _doneTargetSize,
          child: Center(
            child: Semantics(
              key: ValueKey<String>('today-habit-done-${entry.habitId}'),
              button: true,
              toggled: entry.done,
              label: 'Done',
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onDone,
                  child: const SizedBox(
                    width: _doneTargetSize,
                    height: _doneTargetSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
