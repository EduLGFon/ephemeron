import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';
import 'slipped_item.dart';

/// Body content for the slipped-task triage sheet.
///
/// Presentation only: items and callbacks are injected.
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
    this.hintLabel,
  });

  final List<SlippedItem> items;
  final void Function(String id) onDone;
  final void Function(String id) onTomorrow;
  final void Function(String id) onPickTime;
  final void Function(String id) onDrop;
  final void Function(String id) onUndoRequested;
  final String Function(SlippedItem item) daysOverdueLabel;
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
        mainAxisSize: MainAxisSize.min,
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return Focus(
                focusNode: _nodes[index],
                onKeyEvent: (node, event) => _handleKey(index, event),
                child: _TriageRow(
                  item: item,
                  overdueText: widget.daysOverdueLabel(item),
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
        ],
      ),
    );
  }
}

class _TriageRow extends StatelessWidget {
  const _TriageRow({
    required this.item,
    required this.overdueText,
    required this.onDone,
    required this.onTomorrow,
    required this.onPickTime,
    required this.onDrop,
  });

  final SlippedItem item;
  final String overdueText;
  final VoidCallback onDone;
  final VoidCallback onTomorrow;
  final VoidCallback onPickTime;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doneAction = CustomSemanticsAction(label: 'Done');
    final tomorrowAction = CustomSemanticsAction(label: 'Tomorrow');
    final pickAction = CustomSemanticsAction(label: 'Pick time');
    final dropAction = CustomSemanticsAction(label: 'Drop');
    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        doneAction: onDone,
        tomorrowAction: onTomorrow,
        pickAction: onPickTime,
        dropAction: onDrop,
      },
      child: Dismissible(
        key: ValueKey<String>('slipped-${item.id}'),
        direction: DismissDirection.horizontal,
        background: Container(
          color: Colors.green,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: StreamSpacing.x4),
          child: const Icon(Icons.check, color: Colors.white),
        ),
        secondaryBackground: Container(
          color: scheme.tertiary,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: StreamSpacing.x4),
          child: const Icon(Icons.schedule, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onDone();
          } else {
            onTomorrow();
          }
          return false;
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: StreamSpacing.x6,
            vertical: StreamSpacing.x2,
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(item.listColorArgb),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: StreamSpacing.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title),
                    Text(
                      overdueText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Done (D)',
                icon: const Icon(Icons.check),
                onPressed: onDone,
              ),
              IconButton(
                tooltip: 'Tomorrow (T)',
                icon: const Icon(Icons.schedule),
                onPressed: onTomorrow,
              ),
              IconButton(
                tooltip: 'Pick time (P)',
                icon: const Icon(Icons.access_time),
                onPressed: onPickTime,
              ),
              IconButton(
                tooltip: 'Drop (X)',
                icon: const Icon(Icons.close),
                onPressed: onDrop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
