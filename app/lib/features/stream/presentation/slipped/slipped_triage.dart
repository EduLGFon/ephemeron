import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'slipped_action_labels.dart';
import 'slipped_item.dart';
import 'slipped_triage_row.dart';

const double slippedTriageItemExtent = 128;

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
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant SlippedTriage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _selectedIndex = _selectedIndex.clamp(0, widget.items.length - 1);
      if (widget.items.isEmpty) _selectedIndex = 0;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (widget.items.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (_selectedIndex < widget.items.length - 1) _selectedIndex++;
      });
      _scrollToSelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (_selectedIndex > 0) _selectedIndex--;
      });
      _scrollToSelection();
      return KeyEventResult.handled;
    }
    final id = widget.items[_selectedIndex].id;
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

  void _scrollToSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _selectedIndex * slippedTriageItemExtent;
      _scrollController.animateTo(
        target,
        duration: StreamMotion.fast,
        curve: StreamMotion.standard,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) => _handleKey(event),
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
                controller: _scrollController,
                itemExtent: slippedTriageItemExtent,
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return SlippedTriageRow(
                    item: item,
                    overdueText: widget.daysOverdueLabel(item),
                    labels: widget.actionLabels,
                    selected: index == _selectedIndex,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
