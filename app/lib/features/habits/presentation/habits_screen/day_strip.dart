// Part of the habits screen library: the compact selected-day strip.
part of '../habits_screen.dart';

/// Days shown in the habit day strip, oldest first, ending on [today].
/// Pure so the range stays testable without building the widget.
List<DateTime> habitDayStripDays(DateTime today, {int count = 14}) {
  final base = DateTime(today.year, today.month, today.day);
  return [
    for (var i = count - 1; i >= 0; i--) base.subtract(Duration(days: i)),
  ];
}

/// Screen-reader label for one day chip.
String habitDayStripSemanticsLabel(
  BuildContext context,
  DateTime day,
  DateTime today,
) {
  final label = DeviceDateFormat.date(context, day);
  return habitDateKey(day) == habitDateKey(today) ? '$label, today' : label;
}

/// One day in the strip. Kept public so widget tests can target a known day.
class HabitDayChip extends StatelessWidget {
  const HabitDayChip({
    super.key,
    required this.day,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final todayKey = habitDateKey(today);
    final key = habitDateKey(day);
    final isToday = key == todayKey;
    return MergeSemantics(
      child: Semantics(
        label: habitDayStripSemanticsLabel(context, day, today),
        selected: selected,
        button: true,
        child: AppChip(
          label: '${DeviceDateFormat.weekday(context, day)} ${day.day}',
          selected: selected,
          dense: true,
          onTap: () {
            AppFeedback.selection();
            onTap();
          },
          tooltip: isToday ? HabitsStrings.of(context).today : null,
        ),
      ),
    );
  }
}

class _DayStrip extends StatefulWidget {
  const _DayStrip({
    required this.selected,
    required this.strings,
    required this.onSelect,
  });

  final String selected;
  final HabitsStrings strings;
  final void Function(String day) onSelect;

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  final ScrollController _controller = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    _revealSelected(animate: false);
  }

  @override
  void didUpdateWidget(covariant _DayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _revealSelected(animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Keeps the selected chip visible, centered when possible. Runs after the
  /// frame so the chip has a render object on first build.
  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _keys[widget.selected]?.currentContext;
      if (target == null) return;
      if (!animate) {
        Scrollable.ensureVisible(target, alignment: 0.5);
        return;
      }
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: AppMotion.duration(context, DsMotion.normal),
        curve: DsMotion.standard,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = habitDateKey(today);
    final days = habitDayStripDays(today);
    final viewingToday = widget.selected == todayKey;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: DsSpace.x8),
              itemBuilder: (context, index) {
                final day = days[index];
                final key = habitDateKey(day);
                return Center(
                  child: HabitDayChip(
                    key: _keys.putIfAbsent(key, GlobalKey.new),
                    day: day,
                    today: today,
                    selected: key == widget.selected,
                    onTap: () => widget.onSelect(key),
                  ),
                );
              },
            ),
          ),
          if (!viewingToday) ...[
            const SizedBox(width: DsSpace.x8),
            AppChip(
              label: widget.strings.today,
              onTap: () {
                AppFeedback.selection();
                widget.onSelect(todayKey);
              },
            ),
          ],
        ],
      ),
    );
  }
}
