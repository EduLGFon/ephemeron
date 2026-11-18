part of '../tasks_screen.dart';

class _SmartListChip extends ConsumerWidget {
  const _SmartListChip({
    required this.smartList,
    required this.selected,
    required this.onSelected,
    required this.onLongPress,
  });

  final SmartList smartList;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(smartListTasksProvider(smartList));
    final count = results.maybeWhen(
      data: (tasks) => tasks.length,
      orElse: () => null,
    );
    return AppChip(
      key: ValueKey('task-smart-${smartList.id}'),
      label: count == null ? smartList.name : '${smartList.name} ($count)',
      color: _smartListColor(context, smartList),
      selected: selected,
      onTap: onSelected,
      onLongPress: onLongPress,
    );
  }
}

/// Saved views have no stored colour. A stable hash of the id gives each one a
/// distinct dot without writing data or reading the filter JSON.
Color _smartListColor(BuildContext context, SmartList smartList) {
  var hash = 0;
  for (final unit in smartList.id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return DsCategoryColors.forIndex(hash).fill(Theme.of(context).brightness);
}
