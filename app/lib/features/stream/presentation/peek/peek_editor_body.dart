import 'package:material_ui/material_ui.dart';

import 'peek_actions.dart';
import 'peek_data.dart';
import 'peek_list_selector.dart';
import 'peek_notes_field.dart';
import 'peek_priority_row.dart';
import 'peek_time_row.dart';
import 'peek_title_field.dart';

class PeekEditorBody extends StatelessWidget {
  const PeekEditorBody({
    super.key,
    required this.titleController,
    required this.titleFocusNode,
    required this.titleKey,
    this.titleLabel,
    this.titleError,
    required this.onTitleSubmitted,
    required this.formatTime,
    required this.startMs,
    required this.endMs,
    this.startLabel,
    this.endLabel,
    this.addEndLabel,
    this.clearEndLabel,
    this.endError,
    required this.onPickStart,
    required this.onPickEnd,
    this.onClearEnd,
    this.listLabel,
    this.listOptions,
    required this.listId,
    required this.listName,
    this.onPickList,
    required this.onListChanged,
    required this.priorityLabels,
    required this.priorityIcons,
    required this.priority,
    required this.onPriorityChanged,
    required this.notesController,
    this.notesLabel,
    required this.saveLabel,
    required this.cancelLabel,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController titleController;
  final FocusNode titleFocusNode;
  final Key titleKey;
  final String? titleLabel;
  final String? titleError;
  final VoidCallback onTitleSubmitted;
  final String Function(int ms) formatTime;
  final int startMs;
  final int? endMs;
  final String? startLabel;
  final String? endLabel;
  final String? addEndLabel;
  final String? clearEndLabel;
  final String? endError;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback? onClearEnd;
  final String? listLabel;
  final List<PeekListOption>? listOptions;
  final String? listId;
  final String? listName;
  final Future<String?> Function(BuildContext context)? onPickList;
  final void Function(String? id, String? name) onListChanged;
  final List<String> priorityLabels;
  final List<IconData> priorityIcons;
  final PeekPriority priority;
  final ValueChanged<PeekPriority> onPriorityChanged;
  final TextEditingController notesController;
  final String? notesLabel;
  final String saveLabel;
  final String cancelLabel;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PeekTitleField(
          key: titleKey,
          controller: titleController,
          focusNode: titleFocusNode,
          label: titleLabel,
          errorText: titleError,
          onSubmitted: onTitleSubmitted,
        ),
        const SizedBox(height: 8),
        PeekTimeRow(
          formatTime: formatTime,
          startMs: startMs,
          endMs: endMs,
          startLabel: startLabel,
          endLabel: endLabel,
          addEndLabel: addEndLabel,
          clearEndLabel: clearEndLabel,
          endErrorText: endError,
          onPickStart: onPickStart,
          onPickEnd: onPickEnd,
          onClearEnd: onClearEnd,
        ),
        const SizedBox(height: 8),
        PeekListSelector(
          label: listLabel,
          options: listOptions,
          listId: listId,
          listName: listName,
          onPickList: onPickList,
          onChanged: onListChanged,
        ),
        const SizedBox(height: 8),
        PeekPriorityRow(
          labels: priorityLabels,
          icons: priorityIcons,
          value: priority,
          onChanged: onPriorityChanged,
        ),
        const SizedBox(height: 8),
        PeekNotesField(controller: notesController, label: notesLabel),
        const SizedBox(height: 8),
        PeekActions(
          saveLabel: saveLabel,
          cancelLabel: cancelLabel,
          onSave: onSave,
          onCancel: onCancel,
        ),
      ],
    );
  }
}
