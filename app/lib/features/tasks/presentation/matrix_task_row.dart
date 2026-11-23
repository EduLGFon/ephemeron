// Task row for the matrix board. Keeps the complete control and the
// tap-to-edit area in separate gesture regions, and wraps the row in a long
// press draggable only when the board is in priority mode.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ephemeron/core/time/device_date_format.dart';
import 'package:ephemeron/core/time/time.dart';

import '../../../core/design/components/app_wheel.dart';
import '../../../core/design/components/rows.dart';
import '../../../core/design/tokens.dart';
import '../../../core/ui/app_feedback.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/sources/microsoft_source.dart';
import '../../../domain/tasks/eisenhower.dart';
import '../application/tasks_providers.dart';
import 'task_editor_sheet.dart';
import 'task_list_dialogs.dart';

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
    final content = _MatrixTaskRowContent(
      task: task,
      list: list,
      readOnly: readOnly,
    );
    if (!draggable || readOnly) return content;
    return LongPressDraggable<Task>(
      data: task,
      feedback: _TaskDragFeedback(title: task.title),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _MatrixTaskRowContent(
          task: task,
          list: list,
          readOnly: readOnly,
        ),
      ),
      child: content,
    );
  }
}

class _MatrixTaskRowContent extends ConsumerWidget {
  const _MatrixTaskRowContent({
    required this.task,
    this.list,
    this.readOnly = false,
  });

  final Task task;
  final TaskList? list;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppTaskRow(
      title: task.title,
      subtitle: _dueLabel(context),
      listColor: list == null ? null : taskListColor(list!),
      leading: task.priority > 0
          ? AppPriorityFlag(
              flag: priorityFlag(task.priority),
              dense: true,
              showLabel: false,
            )
          : null,
      overdue: _isLate(),
      dense: true,
      onTap: readOnly ? null : () => showTaskEditor(context, task: task),
      onToggle: readOnly ? null : () => _complete(context, ref),
    );
  }

  String? _dueLabel(BuildContext context) {
    final raw = task.dueDate;
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final minutes = task.dueTime;
    final time = minutes == null
        ? null
        : DeviceDateFormat.time(
            context,
            DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60),
          );
    final today = dateKey(DateTime.now());
    if (dateKey(parsed) == today) return time ?? 'Today';

    final date = DeviceDateFormat.shortDate(context, parsed);
    if (_isLate() && time != null) return '$date, $time';
    return date;
  }

  bool _isLate() {
    final raw = task.dueDate;
    if (raw == null || raw.isEmpty) return false;
    final today = dateKey(DateTime.now());
    final parsed = DateTime.tryParse(raw);
    return parsed == null
        ? raw.compareTo(today) < 0
        : dateKey(parsed).compareTo(today) < 0;
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
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DsRadius.r12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpace.x12,
            vertical: DsSpace.x8,
          ),
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
