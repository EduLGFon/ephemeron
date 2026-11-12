part of '../matrix_board.dart';

class _UnclassifiedTray extends StatefulWidget {
  const _UnclassifiedTray({
    super.key,
    required this.tasks,
    required this.dragEnabled,
  });

  final List<Task> tasks;
  final bool dragEnabled;

  @override
  State<_UnclassifiedTray> createState() => _UnclassifiedTrayState();
}

class _UnclassifiedTrayState extends State<_UnclassifiedTray> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(covariant _UnclassifiedTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset scroll position when the tray shrinks so stale offsets do not
    // point past the end of the now-shorter list.
    if (widget.tasks.length < oldWidget.tasks.length &&
        _controller.hasClients) {
      _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Task> get tasks => widget.tasks;

  @override
  Widget build(BuildContext context) {
    if (!widget.dragEnabled) {
      return _buildCard(context, hovering: false);
    }
    return _DropZone(
      priority: 0,
      builder: (context, hovering) => _buildCard(context, hovering: hovering),
    );
  }

  Widget _buildCard(BuildContext context, {required bool hovering}) {
    final theme = Theme.of(context);
    final scaledBody = MediaQuery.textScalerOf(context).scale(14.0);
    final textScale = scaledBody > 0 ? scaledBody / 14.0 : 1.0;
    // Empty trays size to their header/hint so accessibility text cannot
    // overflow a fixed cap; populated trays get a modestly scaled scroll cap.
    final constraints = tasks.isEmpty
        ? const BoxConstraints()
        : BoxConstraints(maxHeight: 140 * textScale.clamp(1.0, 2.0));
    return ConstrainedBox(
      constraints: constraints,
      child: Card(
        key: const ValueKey('matrix-unclassified'),
        margin: EdgeInsets.zero,
        color: hovering ? theme.colorScheme.primaryContainer : null,
        shape: _dropShape(theme, hovering),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Unclassified',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${tasks.length}',
                    key: const ValueKey('matrix-count-unclassified'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No unclassified tasks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Flexible(
                  child: Scrollbar(
                    key: const ValueKey('matrix-scrollbar-unclassified'),
                    controller: _controller,
                    thickness: 2.5,
                    radius: const Radius.circular(2),
                    thumbVisibility: true,
                    interactive: false,
                    child: ListView.builder(
                      key: const ValueKey('matrix-list-unclassified'),
                      controller: _controller,
                      physics:
                          const ClampingScrollPhysics(), // keep inner lists scrollable; outer scroll reaches tray
                      padding: EdgeInsets.zero,
                      itemCount: tasks.length,
                      itemBuilder: (context, index) => MatrixTaskRow(
                        key: ValueKey('matrix-task-${tasks[index].id}'),
                        task: tasks[index],
                        draggable: widget.dragEnabled,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
