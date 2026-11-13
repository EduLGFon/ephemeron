part of '../../search_screen.dart';

class _TagTasksSheet extends ConsumerWidget {
  const _TagTasksSheet({required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(searchTasksForTagProvider(tag.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tag, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tag.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: tasks.when(
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No open tasks',
                    compact: true,
                  );
                }
                final atCap = items.length >= tagTaskLimit;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length + (atCap ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (atCap && i == items.length) {
                      final theme = Theme.of(context);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          'Showing the first $tagTaskLimit open tasks',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final task = items[i];
                    return ListTile(
                      leading: const Icon(Icons.checklist_outlined),
                      title: Text(task.title),
                      onTap: () => showTaskEditor(context, task: task),
                    );
                  },
                );
              },
              loading: () => AppSkeleton.list(context, itemCount: 4),
              error: (_, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load tasks',
                compact: true,
                actionLabel: 'Retry',
                onAction: () =>
                    ref.invalidate(searchTasksForTagProvider(tag.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
