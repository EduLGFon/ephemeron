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
    return _MatrixSurface(
      key: ValueKey('matrix-field-${field.id}'),
      hovering: hovering,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldHeader(
            title: field.title,
            count: field.tasks.length,
            countKey: ValueKey('matrix-count-${field.id}'),
            priority: field.priority,
          ),
          Expanded(
            child: field.tasks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: DsSpace.x4),
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Text(
                        'Empty',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : Scrollbar(
                    key: ValueKey('matrix-scrollbar-${field.id}'),
                    controller: _controller,
                    thickness: 2,
                    radius: const Radius.circular(2),
                    thumbVisibility: true,
                    interactive: false,
                    child: ListView.builder(
                      key: ValueKey('matrix-list-${field.id}'),
                      controller: _controller,
                      physics: const ClampingScrollPhysics(), // inner scroll; outer scroll reaches tray
                      padding: const EdgeInsets.only(top: DsSpace.x4),
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
    );
  }
}
