import 'package:material_ui/material_ui.dart';

import 'peek_data.dart';
import 'peek_editor.dart';

class PeekPanelContent extends StatelessWidget {
  const PeekPanelContent({
    super.key,
    required this.closeLabel,
    required this.onClose,
    required this.data,
    required this.formatTime,
    required this.priorityLabels,
    required this.saveLabel,
    required this.cancelLabel,
    required this.onSave,
    required this.onCancel,
    required this.onDiscardRequested,
    this.listOptions,
    this.onPickTime,
    this.onPickList,
    this.addEndLabel,
    this.clearEndLabel,
    this.emptyTitleLabel,
    this.endBeforeStartLabel,
    this.titleLabel,
    this.startLabel,
    this.endLabel,
    this.listLabel,
    this.notesLabel,
    required this.editorKey,
  });

  final String closeLabel;
  final VoidCallback onClose;
  final PeekData data;
  final String Function(int ms) formatTime;
  final List<String> priorityLabels;
  final String saveLabel;
  final String cancelLabel;
  final void Function(PeekEdit edit) onSave;
  final VoidCallback onCancel;
  final VoidCallback onDiscardRequested;
  final List<PeekListOption>? listOptions;
  final Future<int?> Function(BuildContext context, int currentMs)? onPickTime;
  final Future<String?> Function(BuildContext context)? onPickList;
  final String? addEndLabel;
  final String? clearEndLabel;
  final String? emptyTitleLabel;
  final String? endBeforeStartLabel;
  final String? titleLabel;
  final String? startLabel;
  final String? endLabel;
  final String? listLabel;
  final String? notesLabel;
  final GlobalKey<PeekEditorState> editorKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              tooltip: closeLabel,
            ),
          ],
        ),
        PeekEditor(
          key: editorKey,
          data: data,
          formatTime: formatTime,
          priorityLabels: priorityLabels,
          saveLabel: saveLabel,
          cancelLabel: cancelLabel,
          onSave: onSave,
          onCancel: onCancel,
          onDiscardRequested: onDiscardRequested,
          listOptions: listOptions,
          onPickTime: onPickTime,
          onPickList: onPickList,
          addEndLabel: addEndLabel,
          clearEndLabel: clearEndLabel,
          emptyTitleLabel: emptyTitleLabel ?? '',
          endBeforeStartLabel: endBeforeStartLabel ?? '',
          titleLabel: titleLabel,
          startLabel: startLabel,
          endLabel: endLabel,
          listLabel: listLabel,
          notesLabel: notesLabel,
        ),
      ],
    );
  }
}
