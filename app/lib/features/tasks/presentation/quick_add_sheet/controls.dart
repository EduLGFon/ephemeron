part of '../quick_add_sheet.dart';

/// View metadata for the four capture kinds. Labels stay in [QuickAddStrings]
/// so the enum never hard-codes user-visible text.
extension _QuickAddKindView on _QuickAddKind {
  IconData get icon => switch (this) {
    _QuickAddKind.task => Icons.task_alt,
    _QuickAddKind.event => Icons.event_outlined,
    _QuickAddKind.habit => Icons.repeat,
    _QuickAddKind.countdown => Icons.timer_outlined,
  };

  String label(QuickAddStrings strings) => switch (this) {
    _QuickAddKind.task => strings.typeTask,
    _QuickAddKind.event => strings.typeEvent,
    _QuickAddKind.habit => strings.typeHabit,
    _QuickAddKind.countdown => strings.typeCountdown,
  };

  String addLabel(QuickAddStrings strings) => switch (this) {
    _QuickAddKind.task => strings.addTask,
    _QuickAddKind.event => strings.addEvent,
    _QuickAddKind.habit => strings.addHabit,
    _QuickAddKind.countdown => strings.addCountdown,
  };

  String hint(QuickAddStrings strings) => switch (this) {
    _QuickAddKind.task => strings.fieldHintTask,
    _QuickAddKind.event => strings.fieldHintEvent,
    _QuickAddKind.habit => strings.fieldHintHabit,
    _QuickAddKind.countdown => strings.fieldHintCountdown,
  };
}

/// A labelled vertical wheel. Replaces the old horizontal chip row so every
/// option stays visible without wrapping and the selected value is marked by
/// a check and selection semantics as well as the tonal fill.
class _WheelGroup<T> extends StatelessWidget {
  const _WheelGroup({
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<WheelItem<T>> items;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DsSpace.x4),
        WheelSelector<T>(
          items: items,
          value: value,
          onChanged: onChanged,
          semanticsLabel: label,
        ),
      ],
    );
  }
}
