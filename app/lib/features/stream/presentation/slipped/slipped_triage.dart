import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'slipped_action_labels.dart';
import 'slipped_item.dart';
import 'slipped_triage_row.dart';

class SlippedTriage extends StatefulWidget {
  const SlippedTriage({
    super.key,
    required this.items,
    required this.onDone,
    required this.onTomorrow,
    required this.onPickTime,
    required this.onDrop,
    required this.onUndoRequested,
    required this.daysOverdueLabel,
    required this.actionLabels,
    this.hintLabel,
  });

  final List<SlippedItem> items;
  final void Function(String id) onDone;
  final void Function(String id) onTomorrow;
  final void Function(String id) onPickTime;
  final void Function(String id) onDrop;
  final void Function(String id) onUndoRequested;
  final String Function(SlippedItem item) daysOverdueLabel;
  final SlippedActionLabels actionLabels;
  final String? hintLabel;

  @override
  State<SlippedTriage> createState() => _SlippedTriageState();
}

class _SlippedTriageState extends State<SlippedTriage> {
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = List<FocusNode>.generate(widget.items.length, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_nodes.isNotEmpty && mounted) _nodes.first.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant SlippedTriage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      for (final n in _nodes) {
        n.dispose();
      }
      _nodes
        ..clear()
        ..addAll(
          List<FocusNode>.generate(widget.items.length, (_) => FocusNode()),
        );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_nodes.isNotEmpty && mounted) _nodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (index >= widget.items.length) return KeyEventResult.ignored;
    final id = widget.items[index].id;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (index + 1 < _nodes.length) _nodes[index + 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (index - 1 >= 0) _nodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyD) {
      widget.onDone(id);
      widget.onUndoRequested(id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyT) {
      widget.onTomorrow(id);
      widget.onUndoRequested(id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyP) {
      widget.onPickTime(id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX) {
      widget.onDrop(id);
      widget.onUndoRequested(id);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.hintLabel != null)
            Padding(
              padding: const EdgeInsetsDirectional.all(StreamSpacing.x2),
              child: Text(
                widget.hintLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return Focus(
                  focusNode: _nodes[index],
                  onKeyEvent: (node, event) => _handleKey(index, event),
                  child: SlippedTriageRow(
                    item: item,
                    overdueText: widget.daysOverdueLabel(item),
                    labels: widget.actionLabels,
                    onDone: () {
                      widget.onDone(item.id);
                      widget.onUndoRequested(item.id);
                    },
                    onTomorrow: () {
                      widget.onTomorrow(item.id);
                      widget.onUndoRequested(item.id);
                    },
                    onPickTime: () => widget.onPickTime(item.id),
                    onDrop: () {
                      widget.onDrop(item.id);
                      widget.onUndoRequested(item.id);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
