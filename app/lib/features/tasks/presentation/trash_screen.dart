// Trash: restore, permanent delete, empty old items. Permanent deletion uses
// the shared 6 s undo snack bar instead of a second confirmation dialog.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_feedback.dart';
import '../../../core/ui/empty_state.dart';
import '../../sync/application/pending_operations.dart';
import '../application/tasks_providers.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashAsync = ref.watch(trashProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          TextButton(
            onPressed: () async {
              final ids = await ref.read(taskRepositoryProvider).oldTrashIds();
              if (!context.mounted) return;
              if (ids.isEmpty) {
                showAppSnackBar(context, 'Nothing to purge');
                return;
              }
              final pending = ref.read(pendingOperationsProvider);
              final opIds = await pending.scheduleTaskPurgeAll(ids);
              AppFeedback.warning();
              if (!context.mounted) return;
              showUndoSnackBar(
                context,
                'Purged ${ids.length} old items',
                onUndo: () => pending.cancelAll(opIds),
              );
            },
            child: const Text('Empty old'),
          ),
        ],
      ),
      body: trashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load trash.')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const EmptyState(
              icon: Icons.delete_outline,
              title: 'Trash is empty',
              subtitle: 'Deleted tasks wait here before they are removed.',
            );
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, i) {
              final t = tasks[i];
              final scheme = Theme.of(context).colorScheme;
              return Dismissible(
                key: ValueKey(t.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: scheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(Icons.delete_forever, color: scheme.onError),
                ),
                onDismissed: (_) async {
                  final pending = ref.read(pendingOperationsProvider);
                  final opId = await pending.scheduleTaskPurge(t.id);
                  AppFeedback.warning();
                  if (!context.mounted) return;
                  showUndoSnackBar(
                    context,
                    'Deleted "${t.title}" forever',
                    onUndo: () => pending.cancel(opId),
                  );
                },
                child: ListTile(
                  title: Text(t.title),
                  trailing: IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: 'Restore',
                    onPressed: () async {
                      await ref.read(taskRepositoryProvider).restoreTasks([
                        t.id,
                      ]);
                      AppFeedback.success();
                      if (!context.mounted) return;
                      showAppSnackBar(
                        context,
                        'Restored "${t.title}"',
                        icon: Icons.restore,
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
