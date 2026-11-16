import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import 'peek_data.dart';

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
    this.priorityIcons = const [
      Icons.flag_outlined,
      Icons.flag,
      Icons.priority_high,
      Icons.whatshot,
    ],
  });

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
  final List<IconData> priorityIcons;

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
  late int _startMs = widget.data.startMs;
  late int? _endMs = widget.data.endMs;
  late String? _listId = widget.data.listId;
  late String? _listName = widget.data.listName;
  late PeekPriority _priority = widget.data.priority;

  final FocusNode _rootFocus = FocusNode();

  bool get hasChanges {
    return _title.text != widget.data.title ||
        _startMs != widget.data.startMs ||
        _endMs != widget.data.endMs ||
        _listId != widget.data.listId ||
        _priority != widget.data.priority ||
        (_notes.text) != (widget.data.notes ?? '');
  }

  void _save() {
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

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _rootFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rootFocus,
      autofocus: false,
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
            TextField(
              controller: _title,
              autofocus: true,
              decoration: InputDecoration(labelText: widget.titleLabel),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: widget.startLabel,
                    value: widget.formatTime(_startMs),
                    onTap: widget.onPickTime == null
                        ? null
                        : () async {
                            final v = await widget.onPickTime!(
                              context,
                              _startMs,
                            );
                            if (v != null) setState(() => _startMs = v);
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeField(
                    label: widget.endLabel,
                    value: _endMs == null ? '' : widget.formatTime(_endMs!),
                    onTap: widget.onPickTime == null || _endMs == null
                        ? null
                        : () async {
                            final v = await widget.onPickTime!(
                              context,
                              _endMs!,
                            );
                            if (v != null) setState(() => _endMs = v);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ListSelector(
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<PeekPriority>(
                segments: [
                  for (var i = 0; i < PeekPriority.values.length; i++)
                    ButtonSegment<PeekPriority>(
                      value: PeekPriority.values[i],
                      label: Text(widget.priorityLabels[i]),
                      icon: Icon(widget.priorityIcons[i]),
                    ),
                ],
                selected: {_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.single),
              ),
            ),
            const SizedBox(height: 8),
            // Notes field height range: 72..160 dp.
            SizedBox(
              height: 120,
              child: TextField(
                controller: _notes,
                decoration: InputDecoration(labelText: widget.notesLabel),
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(onPressed: _cancel, child: Text(widget.cancelLabel)),
                FilledButton(onPressed: _save, child: Text(widget.saveLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({this.label, required this.value, this.onTap});
  final String? label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value),
      ),
    );
  }
}

class _ListSelector extends StatelessWidget {
  const _ListSelector({
    this.label,
    this.options,
    required this.listId,
    required this.listName,
    this.onPickList,
    required this.onChanged,
  });

  final String? label;
  final List<PeekListOption>? options;
  final String? listId;
  final String? listName;
  final Future<String?> Function(BuildContext context)? onPickList;
  final void Function(String? id, String? name) onChanged;

  @override
  Widget build(BuildContext context) {
    if (options != null && options!.isNotEmpty) {
      return DropdownButtonFormField<String?>(
        initialValue: listId,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: SizedBox.shrink(),
          ),
          for (final o in options!)
            DropdownMenuItem<String?>(value: o.id, child: Text(o.name)),
        ],
        onChanged: (v) {
          final name = v == null
              ? null
              : options!.firstWhere((o) => o.id == v).name;
          onChanged(v, name);
        },
      );
    }
    return InkWell(
      onTap: onPickList == null
          ? null
          : () async {
              final v = await onPickList!(context);
              onChanged(v, listName);
            },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(listName ?? ''),
      ),
    );
  }
}
