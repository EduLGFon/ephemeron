// Eisenhower matrix screen: switches between auto classification and stored
// priority grouping, and hosts the board plus task creation entry point.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/app_headers.dart';
import '../../../core/design/components/app_wheel.dart';
import '../../../core/design/components/app_page.dart';
import '../../../core/design/components/app_states.dart';
import '../../../core/design/components/sync_indicator.dart';
import '../../../core/design/tokens.dart';
import '../../../core/ui/app_feedback.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/tasks/eisenhower.dart';
import '../../sync/application/sync_providers.dart';
import '../../sync/data/sync_engine.dart';
import '../application/tasks_providers.dart';
import 'matrix_board.dart';

class MatrixScreen extends ConsumerWidget {
  const MatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(openTasksProvider(null));
    final modeAsync = ref.watch(matrixModeProvider);
    // Do not render the Auto board while the saved mode is still loading:
    // a cold start would otherwise flash Auto before Priority arrives. Only a
    // real error falls back to Auto.
    final mode =
        modeAsync.value ?? (modeAsync.hasError ? MatrixMode.auto : null);
    return AppPage(
      header: AppPageHeader(
        title: const Text(
          'Matrix',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final status = ref.watch(combinedSyncStatusProvider);
              return AppSyncIndicator(
                state: switch (status) {
                  SyncStatus.synced => AppSyncState.synced,
                  SyncStatus.syncing => AppSyncState.syncing,
                  SyncStatus.offline => AppSyncState.offline,
                  SyncStatus.error => AppSyncState.attention,
                },
                tooltip: 'Sync now',
                onTap: () {
                  AppFeedback.tap();
                  ref.read(syncAllProvider)();
                },
              );
            },
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(DsSpace.x16, 0, DsSpace.x16, 0),
      child: mode == null
          ? const Center(
              child: SizedBox.square(
                dimension: DsSpace.x24,
                child: CircularProgressIndicator(
                  key: Key('matrix-mode-loading'),
                  strokeWidth: 2,
                ),
              ),
            )
          : tasksAsync.when(
              loading: () => const AppSkeletonList(rows: 4),
              error: (e, _) => AppErrorState(
                title: 'Could not load matrix',
                message: 'Check your connection and try again.',
                onRetry: () => ref.invalidate(openTasksProvider(null)),
              ),
              data: (tasks) {
                final grouped = _groupTasks(tasks, mode);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: DsSpace.x8),
                      child: _ModeSelector(mode: mode),
                    ),
                    Expanded(
                      child: MatrixBoard(
                        fields: grouped.fields,
                        unclassified: grouped.unclassified,
                        mode: mode,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _ModeSelector extends ConsumerWidget {
  const _ModeSelector({required this.mode});

  final MatrixMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(MatrixMode next) {
      if (next == mode) return;
      ref.read(matrixModeProvider.notifier).select(next);
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: WheelSelector<MatrixMode>(
          items: const <WheelItem<MatrixMode>>[
            WheelItem<MatrixMode>(
              value: MatrixMode.auto,
              label: 'Auto',
              icon: Icons.auto_awesome_outlined,
              key: ValueKey('matrix-mode-auto'),
            ),
            WheelItem<MatrixMode>(
              value: MatrixMode.priority,
              label: 'Priority',
              icon: Icons.flag_outlined,
              key: ValueKey('matrix-mode-priority'),
            ),
          ],
          value: mode,
          onChanged: select,
          semanticsLabel: 'Matrix mode',
        ),
      ),
    );
  }
}

({List<MatrixBoardField> fields, List<Task> unclassified}) _groupTasks(
  List<Task> tasks,
  MatrixMode mode,
) {
  if (mode == MatrixMode.priority) {
    final buckets = <int, List<Task>>{4: [], 3: [], 2: [], 1: []};
    final unclassified = <Task>[];
    for (final task in tasks) {
      final bucket = buckets[task.priority];
      if (bucket == null) {
        unclassified.add(task);
      } else {
        bucket.add(task);
      }
    }
    return (
      fields: [
        for (final priority in const [4, 3, 2, 1])
          MatrixBoardField(
            id: matrixPriorityLabel(priority)!.toLowerCase(),
            title: matrixPriorityLabel(priority)!,
            tasks: buckets[priority]!,
          ),
      ],
      unclassified: unclassified,
    );
  }

  final groups = <EisenhowerQuadrant, List<Task>>{
    for (final quadrant in EisenhowerQuadrant.values) quadrant: [],
  };
  final now = DateTime.now();
  for (final task in tasks) {
    final dueDate = task.dueDate == null
        ? null
        : DateTime.tryParse(task.dueDate!);
    groups[classifyTask(priority: task.priority, dueDate: dueDate, now: now)]!
        .add(task);
  }
  return (
    fields: [
      MatrixBoardField(
        id: 'doFirst',
        title: 'Do first',
        tasks: groups[EisenhowerQuadrant.doFirst]!,
      ),
      MatrixBoardField(
        id: 'schedule',
        title: 'Schedule',
        tasks: groups[EisenhowerQuadrant.schedule]!,
      ),
      MatrixBoardField(
        id: 'delegate',
        title: 'Delegate',
        tasks: groups[EisenhowerQuadrant.delegate]!,
      ),
      MatrixBoardField(
        id: 'eliminate',
        title: 'Eliminate',
        tasks: groups[EisenhowerQuadrant.eliminate]!,
      ),
    ],
    unclassified: groups[EisenhowerQuadrant.unclassified]!,
  );
}
