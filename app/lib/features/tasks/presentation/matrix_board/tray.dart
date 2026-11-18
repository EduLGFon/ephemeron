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
        : BoxConstraints(maxHeight: _trayMaxHeight * textScale.clamp(1.0, 2.0));
    return _MatrixSurface(
      key: const ValueKey('matrix-unclassified'),
      hovering: hovering,
      constraints: constraints,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FieldHeader(
            title: 'Unclassified',
            count: tasks.length,
            countKey: const ValueKey('matrix-count-unclassified'),
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.x4),
              child: Text(
                'No unclassified tasks',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                thickness: 2,
                radius: const Radius.circular(2),
                thumbVisibility: true,
                interactive: false,
                child: ListView.builder(
                  key: const ValueKey('matrix-list-unclassified'),
                  controller: _controller,
                  physics: const ClampingScrollPhysics(), // keep inner lists scrollable; outer scroll reaches tray
                  padding: const EdgeInsets.only(top: DsSpace.x4),
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
    );
  }
}
