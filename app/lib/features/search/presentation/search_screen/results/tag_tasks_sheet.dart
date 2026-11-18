part of '../../search_screen.dart';

class _TagTasksSheet extends ConsumerWidget {
  const _TagTasksSheet({required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = SearchStrings.of(context);
    final tasks = ref.watch(searchTasksForTagProvider(tag.id));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          title: tag.name,
          leading: const Icon(Icons.tag, size: DsIcon.md),
        ),
        Flexible(
          child: tasks.when(
            data: (items) {
              if (items.isEmpty) {
                return AppEmptyState(
                  icon: Icons.inbox_outlined,
                  title: strings.noOpenTasks,
                );
              }
              final atCap = items.length >= tagTaskLimit;
              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  DsSpace.x16,
                  0,
                  DsSpace.x16,
                  DsSpace.x16,
                ),
                itemCount: items.length + (atCap ? 1 : 0),
                itemBuilder: (_, i) {
                  if (atCap && i == items.length) {
                    final theme = Theme.of(context);
                    return Padding(
                      padding: const EdgeInsets.only(
                        left: DsSpace.x12,
                        top: DsSpace.x8,
                      ),
                      child: Text(
                        strings.tagTaskCap(tagTaskLimit),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final task = items[i];
                  return _ResultRow(
                    icon: Icons.checklist_outlined,
                    title: task.title,
                    onTap: () => showTaskEditor(context, task: task),
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(DsSpace.x16),
              child: AppSkeletonList(rows: 4),
            ),
            error: (_, _) => AppEmptyState(
              icon: Icons.error_outline,
              title: strings.couldNotLoadTasks,
              actionLabel: strings.retry,
              onAction: () => ref.invalidate(searchTasksForTagProvider(tag.id)),
            ),
          ),
        ),
      ],
    );
  }
}
