import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import 'peek_actions.dart';
import 'peek_data.dart';
import 'peek_list_selector.dart';
import 'peek_notes_field.dart';
import 'peek_priority_row.dart';
import 'peek_time_row.dart';
import 'peek_title_field.dart';

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
    this.emptyTitleLabel,
    this.endBeforeStartLabel,
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
  final String? emptyTitleLabel;
  final String? endBeforeStartLabel;
  final List<IconData> priorityIcons;
  final Key? titleKey;

  @override
  State<PeekEditor> createState() => PeekEditorState();
}

class PeekEditorState extends State<PeekEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.data.title,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.data.notes ?? '',
  );
  late final FocusNode titleFocusNode = FocusNode();
  late PeekData _baseline = widget.data;
  late int _startMs = widget.data.startMs;
  late int? _endMs = widget.data.endMs;
  late String? _listId = widget.data.listId;
  late String? _listName = widget.data.listName;
  late PeekPriority _priority = widget.data.priority;
  String? _titleError;
  String? _endError;

  bool get hasChanges {
    return _title.text != _baseline.title ||
        _startMs != _baseline.startMs ||
        _endMs != _baseline.endMs ||
        _listId != _baseline.listId ||
        _priority != _baseline.priority ||
        (_notes.text) != (_baseline.notes ?? '');
  }

  void _reseed(PeekData data) {
    _title.text = data.title;
    _notes.text = data.notes ?? '';
    _startMs = data.startMs;
    _endMs = data.endMs;
    _listId = data.listId;
    _listName = data.listName;
    _priority = data.priority;
    _baseline = data;
    _titleError = null;
    _endError = null;
  }

  @override
  void didUpdateWidget(covariant PeekEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.id != oldWidget.data.id) {
      _reseed(widget.data);
    } else if (!hasChanges && widget.data != oldWidget.data) {
      _reseed(widget.data);
    }
    // If the user is dirty and the same mark changes, keep the user's edit.
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() => _titleError = widget.emptyTitleLabel);
      return;
    }
    if (_endMs != null && _endMs! < _startMs) {
      setState(() => _endError = widget.endBeforeStartLabel);
      return;
    }
    _titleError = null;
    _endError = null;
    widget.onSave(
      PeekEdit(
        title: _title.text,
        startMs: _startMs,
        endMs: _endMs,
        listId: _listId,
        priority: _priority,
        notes: _notes.text.isEmpty ? null : _notes.text,
      ),
    );
  }

  void _cancel() {
    if (hasChanges) {
      widget.onDiscardRequested();
    } else {
      widget.onCancel();
    }
  }

  Future<void> _pickStart() async {
    if (widget.onPickTime == null) return;
    final v = await widget.onPickTime!(context, _startMs);
    if (v != null) setState(() => _startMs = v);
  }

  Future<void> _pickEnd() async {
    if (widget.onPickTime == null) return;
    final current = _endMs ?? _startMs + 30 * 60 * 1000;
    final v = await widget.onPickTime!(context, current);
    setState(() => _endMs = v);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _cancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PeekTitleField(
              key: widget.titleKey ?? const ValueKey('peek_title_field'),
              controller: _title,
              focusNode: titleFocusNode,
              label: widget.titleLabel,
              errorText: _titleError,
              onSubmitted: _save,
            ),
            const SizedBox(height: 8),
            PeekTimeRow(
              formatTime: widget.formatTime,
              startMs: _startMs,
              endMs: _endMs,
              startLabel: widget.startLabel,
              endLabel: widget.endLabel,
              addEndLabel: widget.addEndLabel,
              clearEndLabel: widget.clearEndLabel,
              endErrorText: _endError,
              onPickStart: _pickStart,
              onPickEnd: _pickEnd,
              onClearEnd: widget.clearEndLabel == null
                  ? null
                  : () => setState(() => _endMs = null),
            ),
            const SizedBox(height: 8),
            PeekListSelector(
              label: widget.listLabel,
              options: widget.listOptions,
              listId: _listId,
              listName: _listName,
              onPickList: widget.onPickList,
              onChanged: (id, name) => setState(() {
                _listId = id;
                _listName = name;
              }),
            ),
            const SizedBox(height: 8),
            PeekPriorityRow(
              labels: widget.priorityLabels,
              icons: widget.priorityIcons,
              value: _priority,
              onChanged: (p) => setState(() => _priority = p),
            ),
            const SizedBox(height: 8),
            PeekNotesField(controller: _notes, label: widget.notesLabel),
            const SizedBox(height: 8),
            PeekActions(
              saveLabel: widget.saveLabel,
              cancelLabel: widget.cancelLabel,
              onSave: _save,
              onCancel: _cancel,
            ),
          ],
        ),
      ),
    );
  }
}
