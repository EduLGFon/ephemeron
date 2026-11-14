// Task row for the matrix board. Keeps the complete checkbox and the
// tap-to-edit area in separate gesture regions, and wraps the row in a long
// press draggable only when the board is in priority mode.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ephemeron/core/time/device_date_format.dart';

import '../../../core/ui/app_feedback.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/sources/microsoft_source.dart';
import '../application/tasks_providers.dart';
import 'task_editor_sheet.dart';

class MatrixTaskRow extends ConsumerWidget {
  const MatrixTaskRow({super.key, required this.task, required this.draggable});

  final Task task;
  final bool draggable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = task.listId == null
        ? null
        : ref.watch(taskListsByIdProvider)[task.listId];
    final isMs = isMicrosoftTask(
      taskMicrosoftAccount: task.microsoftAccount,
      listMicrosoftAccount: list?.microsoftAccount,
    );
    final readOnly = isMs;
    final content = _MatrixTaskRowContent(task: task, readOnly: readOnly);
    if (!draggable || readOnly) return content;
    return LongPressDraggable<Task>(
      data: task,
      feedback: _TaskDragFeedback(title: task.title),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _MatrixTaskRowContent(task: task, readOnly: readOnly),
      ),
      child: content,
    );
  }
}

class _MatrixTaskRowContent extends ConsumerWidget {
  const _MatrixTaskRowContent({required this.task, this.readOnly = false});

  final Task task;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dueLabel = _dueLabel(context);
    // Compact single-line row: the small checkbox and the title/date line are
    // sized to stay around 40 px tall at 1x text so many tasks fit per field.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        children: [
          Tooltip(
            message: 'Mark "${task.title}" concluded',
            child: SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                key: ValueKey('matrix-complete-${task.id}'),
                value: false,
                shape: const CircleBorder(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: readOnly ? null : (_) => _complete(context, ref),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: readOnly
                  ? null
                  : () => showTaskEditor(context, task: task),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (dueLabel != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        dueLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _dueLabel(BuildContext context) {
    final raw = task.dueDate;
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : DeviceDateFormat.shortDate(context, parsed);
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(taskRepositoryProvider);
    AppFeedback.success();
    await repo.completeTask(task.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      'Completed "${task.title}"',
      onUndo: () => repo.uncompleteTask(task.id),
    );
  }
}

class _TaskDragFeedback extends StatelessWidget {
  const _TaskDragFeedback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
