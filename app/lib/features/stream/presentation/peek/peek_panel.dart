import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'peek_data.dart';
import 'peek_editor_state.dart';
import 'peek_panel_content.dart';

/// Expanding inline container for a Stream Peek.
class PeekPanel extends StatefulWidget {
  const PeekPanel({
    super.key,
    required this.data,
    this.expanded = true,
    this.expandedListenable,
    this.editorKey,
    required this.formatTime,
    required this.priorityLabels,
    required this.saveLabel,
    required this.cancelLabel,
    required this.closeLabel,
    required this.panelLabel,
    required this.onSave,
    required this.onCancel,
    required this.onDiscardRequested,
    required this.emptyTitleLabel,
    required this.endBeforeStartLabel,
    this.isDirty,
    this.listOptions,
    this.onPickTime,
    this.onPickList,
    this.addEndLabel,
    this.clearEndLabel,
    this.titleLabel,
    this.startLabel,
    this.endLabel,
    this.listLabel,
    this.notesLabel,
  });

  final PeekData data;
  final bool expanded;
  final ValueListenable<bool>? expandedListenable;
  final GlobalKey<PeekEditorState>? editorKey;
  final String Function(int ms) formatTime;
  final List<String> priorityLabels;
  final String saveLabel;
  final String cancelLabel;
  final String closeLabel;
  final String panelLabel;
  final void Function(PeekEdit edit) onSave;
  final VoidCallback onCancel;
  final VoidCallback onDiscardRequested;
  final String emptyTitleLabel;
  final String endBeforeStartLabel;
  final bool Function()? isDirty;
  final List<PeekListOption>? listOptions;
  final Future<int?> Function(BuildContext context, int currentMs)? onPickTime;
  final Future<String?> Function(BuildContext context)? onPickList;
  final String? addEndLabel;
  final String? clearEndLabel;
  final String? titleLabel;
  final String? startLabel;
  final String? endLabel;
  final String? listLabel;
  final String? notesLabel;

  @override
  State<PeekPanel> createState() => _PeekPanelState();
}

class _PeekPanelState extends State<PeekPanel> {
  late bool _expanded = widget.expanded;
  late ValueListenable<bool>? _listenable = widget.expandedListenable;
  late final GlobalKey<PeekEditorState> _editorKey =
      widget.editorKey ?? GlobalKey<PeekEditorState>();

  @override
  void initState() {
    super.initState();
    _listenable?.addListener(_onListen);
  }

  void _onListen() {
    if (_listenable == null) return;
    setState(() => _expanded = _listenable!.value);
  }

  @override
  void dispose() {
    _listenable?.removeListener(_onListen);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PeekPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded &&
        widget.expandedListenable == null) {
      _expanded = widget.expanded;
    }
    if (oldWidget.expandedListenable != widget.expandedListenable) {
      _listenable?.removeListener(_onListen);
      _listenable = widget.expandedListenable;
      _listenable?.addListener(_onListen);
      if (_listenable != null) {
        _expanded = _listenable!.value;
      }
    }
  }

  bool get _isDirty {
    if (_editorKey.currentState != null) {
      return _editorKey.currentState!.hasChanges;
    }
    return widget.isDirty?.call() ?? false;
  }

  void _close() {
    if (_isDirty) {
      widget.onDiscardRequested();
    } else {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final content = _expanded
        ? PeekPanelContent(
            closeLabel: widget.closeLabel,
            onClose: _close,
            data: widget.data,
            formatTime: widget.formatTime,
            priorityLabels: widget.priorityLabels,
            saveLabel: widget.saveLabel,
            cancelLabel: widget.cancelLabel,
            onSave: widget.onSave,
            onCancel: widget.onCancel,
            onDiscardRequested: widget.onDiscardRequested,
            listOptions: widget.listOptions,
            onPickTime: widget.onPickTime,
            onPickList: widget.onPickList,
            addEndLabel: widget.addEndLabel,
            clearEndLabel: widget.clearEndLabel,
            emptyTitleLabel: widget.emptyTitleLabel,
            endBeforeStartLabel: widget.endBeforeStartLabel,
            titleLabel: widget.titleLabel,
            startLabel: widget.startLabel,
            endLabel: widget.endLabel,
            listLabel: widget.listLabel,
            notesLabel: widget.notesLabel,
            editorKey: _editorKey,
          )
        : const SizedBox.shrink();
    if (reduce) {
      return Semantics(
        container: true,
        label: widget.panelLabel,
        child: content,
      );
    }
    return Semantics(
      container: true,
      label: widget.panelLabel,
      child: AnimatedSize(
        duration: StreamMotion.normal,
        curve: StreamMotion.standard,
        child: content,
      ),
    );
  }
}
