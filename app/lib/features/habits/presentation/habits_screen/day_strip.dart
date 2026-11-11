// Part of the habits screen library: the scrollable selected-day strip.
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

class _DayStrip extends StatefulWidget {
  const _DayStrip({required this.selected, required this.onSelect});

  final String selected;
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
      final context = _keys[widget.selected]?.currentContext;
      if (context == null) return;
      if (!animate) {
        Scrollable.ensureVisible(context, alignment: 0.5);
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: AppMotion.duration(context, AppDurations.normal),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = habitDateKey(today);
    final days = habitDayStripDays(today);
    final viewingToday = widget.selected == todayKey;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Row(
                children: [
                  for (final day in days) ...[
                    _dayChip(context, day, today, theme, scheme),
                    const SizedBox(width: AppSpace.xs),
                  ],
                ],
              ),
            ),
          ),
          if (!viewingToday)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.sm),
              child: TextButton(
                onPressed: () {
                  AppFeedback.selection();
                  widget.onSelect(todayKey);
                },
                child: const Text('Today'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayChip(
    BuildContext context,
    DateTime day,
    DateTime today,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final key = habitDateKey(day);
    final selected = key == widget.selected;
    final isToday = key == habitDateKey(today);
    final chipKey = _keys.putIfAbsent(key, GlobalKey.new);
    return Semantics(
      label: habitDayStripSemanticsLabel(context, day, today),
      selected: selected,
      button: true,
      child: ChoiceChip(
        key: chipKey,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: AppSpace.xxs,
        ),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DeviceDateFormat.weekday(context, day),
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? scheme.onSecondaryContainer : null,
              ),
            ),
            Text(
              '${day.day}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                color: selected ? scheme.onSecondaryContainer : null,
              ),
            ),
          ],
        ),
        selected: selected,
        onSelected: (_) {
          AppFeedback.selection();
          widget.onSelect(key);
        },
      ),
    );
  }
}
