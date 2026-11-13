part of '../task_action_sheet.dart';

abstract class _TaskActionSheetBase extends ConsumerWidget {
  const _TaskActionSheetBase({
    super.key,
    required this.taskId,
    required this.occurrenceDate,
  });

  final String taskId;
  final String occurrenceDate;
}

class TaskActionSheet extends _TaskActionSheetBase
    with
        _TaskActionSheetActions,
        _TaskActionSheetSections,
        _TaskActionSheetView {
  const TaskActionSheet({
    super.key,
    required super.taskId,
    required super.occurrenceDate,
  });
}
