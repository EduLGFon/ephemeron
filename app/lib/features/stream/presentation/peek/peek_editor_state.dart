import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import 'peek_data.dart';
import 'peek_editor.dart';
import 'peek_editor_body.dart';

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

  @override
  void initState() {
    super.initState();
    _title.addListener(_clearTitleError);
  }

  void _clearTitleError() {
    if (_titleError != null && mounted) {
      setState(() => _titleError = null);
    }
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
    if (!mounted) return;
    if (v != null) {
      setState(() {
        _startMs = v;
        _endError = null;
      });
    }
  }

  Future<void> _pickEnd() async {
    if (widget.onPickTime == null) return;
    final current = _endMs ?? _startMs + 30 * 60 * 1000;
    final v = await widget.onPickTime!(context, current);
    if (!mounted) return;
    if (v != null) {
      setState(() {
        _endMs = v;
        _endError = null;
      });
    }
  }

  void _clearEnd() {
    setState(() {
      _endMs = null;
      _endError = null;
    });
  }

  @override
  void dispose() {
    _title.removeListener(_clearTitleError);
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
        child: PeekEditorBody(
          titleController: _title,
          titleFocusNode: titleFocusNode,
          titleKey: widget.titleKey ?? const ValueKey('peek_title_field'),
          titleLabel: widget.titleLabel,
          titleError: _titleError,
          onTitleSubmitted: _save,
          formatTime: widget.formatTime,
          startMs: _startMs,
          endMs: _endMs,
          startLabel: widget.startLabel,
          endLabel: widget.endLabel,
          addEndLabel: widget.addEndLabel,
          clearEndLabel: widget.clearEndLabel,
          endError: _endError,
          onPickStart: _pickStart,
          onPickEnd: _pickEnd,
          onClearEnd: widget.clearEndLabel == null ? null : _clearEnd,
          listLabel: widget.listLabel,
          listOptions: widget.listOptions,
          listId: _listId,
          listName: _listName,
          onPickList: widget.onPickList,
          onListChanged: (id, name) => setState(() {
            _listId = id;
            _listName = name;
          }),
          priorityLabels: widget.priorityLabels,
          priorityIcons: widget.priorityIcons,
          priority: _priority,
          onPriorityChanged: (p) => setState(() => _priority = p),
          notesController: _notes,
          notesLabel: widget.notesLabel,
          saveLabel: widget.saveLabel,
          cancelLabel: widget.cancelLabel,
          onSave: _save,
          onCancel: _cancel,
        ),
      ),
    );
  }
}
