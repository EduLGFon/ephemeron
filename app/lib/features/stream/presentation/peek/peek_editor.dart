import 'package:material_ui/material_ui.dart';

import 'peek_data.dart';
import 'peek_editor_state.dart';

/// Inline editor body for a Stream Peek.
class PeekEditor extends StatefulWidget {
  const PeekEditor({
    super.key,
    required this.data,
    required this.formatTime,
    required this.priorityLabels,
    required this.saveLabel,
    required this.cancelLabel,
    required this.onSave,
    required this.onCancel,
    required this.onDiscardRequested,
    required this.emptyTitleLabel,
    required this.endBeforeStartLabel,
    this.listOptions,
    this.onPickTime,
    this.onPickList,
    this.titleLabel,
    this.startLabel,
    this.endLabel,
    this.listLabel,
    this.notesLabel,
    this.addEndLabel,
    this.clearEndLabel,
    this.priorityIcons = const [
      Icons.flag_outlined,
      Icons.flag,
      Icons.priority_high,
      Icons.whatshot,
    ],
    this.titleKey,
  }) : assert(priorityLabels.length == 4),
       assert(priorityIcons.length == 4);

  final PeekData data;
  final String Function(int ms) formatTime;
  final List<String> priorityLabels;
  final String saveLabel;
  final String cancelLabel;
  final void Function(PeekEdit edit) onSave;
  final VoidCallback onCancel;
  final VoidCallback onDiscardRequested;
  final String emptyTitleLabel;
  final String endBeforeStartLabel;
  final List<PeekListOption>? listOptions;
  final Future<int?> Function(BuildContext context, int currentMs)? onPickTime;
  final Future<String?> Function(BuildContext context)? onPickList;
  final String? titleLabel;
  final String? startLabel;
  final String? endLabel;
  final String? listLabel;
  final String? notesLabel;
  final String? addEndLabel;
  final String? clearEndLabel;
  final List<IconData> priorityIcons;
  final Key? titleKey;

  @override
  State<PeekEditor> createState() => PeekEditorState();
}
