import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'peek_data.dart';
import 'peek_editor.dart';

/// Expanding inline container for a Stream Peek.
class PeekPanel extends StatefulWidget {
  const PeekPanel({
    super.key,
    required this.data,
    this.expanded = true,
    this.expandedListenable,
    required this.formatTime,
    required this.priorityLabels,
    required this.saveLabel,
    required this.cancelLabel,
    required this.closeLabel,
    required this.panelLabel,
    required this.onSave,
    required this.onCancel,
    required this.onDiscardRequested,
    this.isDirty,
    this.listOptions,
    this.onPickTime,
    this.onPickList,
  });

  final PeekData data;
  final bool expanded;
  final ValueListenable<bool>? expandedListenable;
  final String Function(int ms) formatTime;
  final List<String> priorityLabels;
  final String saveLabel;
  final String cancelLabel;
  final String closeLabel;
  final String panelLabel;
  final void Function(PeekEdit edit) onSave;
  final VoidCallback onCancel;
  final VoidCallback onDiscardRequested;
  final bool Function()? isDirty;
  final List<PeekListOption>? listOptions;
  final Future<int?> Function(BuildContext context, int currentMs)? onPickTime;
  final Future<String?> Function(BuildContext context)? onPickList;

  @override
  State<PeekPanel> createState() => _PeekPanelState();
}

class _PeekPanelState extends State<PeekPanel> {
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded;
    widget.expandedListenable?.addListener(_onListen);
  }

  void _onListen() {
    setState(() => _expanded = widget.expandedListenable!.value);
  }

  @override
  void dispose() {
    widget.expandedListenable?.removeListener(_onListen);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PeekPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded &&
        widget.expandedListenable == null) {
      _expanded = widget.expanded;
    }
  }

  void _close() {
    if (widget.isDirty != null && widget.isDirty!()) {
      widget.onDiscardRequested();
    } else {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final content = _expanded
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close),
                    tooltip: widget.closeLabel,
                  ),
                ],
              ),
              PeekEditor(
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
              ),
            ],
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
