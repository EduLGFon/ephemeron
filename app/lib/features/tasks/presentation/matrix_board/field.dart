part of '../matrix_board.dart';

class _MatrixField extends StatefulWidget {
  const _MatrixField(
    this.field, {
    super.key,
    required this.dragEnabled,
    required this.dropPriority,
  });

  final MatrixBoardField field;
  final bool dragEnabled;
  final int dropPriority;

  @override
  State<_MatrixField> createState() => _MatrixFieldState();
}

class _MatrixFieldState extends State<_MatrixField> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  MatrixBoardField get field => widget.field;

  @override
  Widget build(BuildContext context) {
    if (!widget.dragEnabled) {
      return _buildCard(context, hovering: false);
    }
    return _DropZone(
      priority: widget.dropPriority,
      builder: (context, hovering) => _buildCard(context, hovering: hovering),
    );
  }

  Widget _buildCard(BuildContext context, {required bool hovering}) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('matrix-field-${field.id}'),
      margin: EdgeInsets.zero,
      color: hovering ? theme.colorScheme.primaryContainer : null,
      shape: _dropShape(theme, hovering),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    field.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${field.tasks.length}',
                  key: ValueKey('matrix-count-${field.id}'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Expanded(
              child: field.tasks.isEmpty
                  ? Center(
                      child: Text(
                        'Empty',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Scrollbar(
                      key: ValueKey('matrix-scrollbar-${field.id}'),
                      controller: _controller,
                      thickness: 2.5,
                      radius: const Radius.circular(2),
                      thumbVisibility: true,
                      interactive: false,
                      child: ListView.builder(
                        key: ValueKey('matrix-list-${field.id}'),
                        controller: _controller,
                        physics: const ClampingScrollPhysics(), // inner scroll; outer scroll reaches tray
                        padding: EdgeInsets.zero,
                        itemCount: field.tasks.length,
                        itemBuilder: (context, index) => MatrixTaskRow(
                          key: ValueKey('matrix-task-${field.tasks[index].id}'),
                          task: field.tasks[index],
                          draggable: widget.dragEnabled,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
