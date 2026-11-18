// Today habits strip. One tap toggles the habit for today; the entry stream is
// the optimistic source of truth, so no local copy is kept.
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
    required this.onToggle,
  });

  final List<HabitCalendarEntry> entries;
  final bool expanded;
  final ValueChanged<HabitCalendarEntry> onToggle;

  @override
  Widget build(BuildContext context) {
    final strings = TodayStrings.of(context);
    final theme = Theme.of(context);
    if (entries.isEmpty) return const SizedBox.shrink();
    final chips = <Widget>[
      for (var i = 0; i < entries.length; i++)
        AppHabitChip(
          key: ValueKey<String>('today-habit-${entries[i].habitId}'),
          name: entries[i].habitName,
          progress: _progress(entries[i]),
          done: entries[i].done,
          color: DsCategoryColors.forIndex(i).fill(theme.brightness),
          onTap: () => onToggle(entries[i]),
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
