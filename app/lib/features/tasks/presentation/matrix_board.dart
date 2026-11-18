// Responsive 2x2 matrix board: four equal fields plus a separate tray for
// tasks that no field claims. Task rows open the editor on tap. In priority
// mode rows can be long-pressed and dragged between fields and the tray, and
// every row carries a complete control.
//
// The board fills the available height on tall screens and falls back to an
// outer scroll on short ones, so quadrant content never forces an overflow.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/app_surface.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/tasks/eisenhower.dart';
import '../application/tasks_providers.dart';
import '../../../domain/sources/microsoft_source.dart';
import 'matrix_task_row.dart';

part 'matrix_board/drop_zone.dart';
part 'matrix_board/field.dart';
part 'matrix_board/tray.dart';

const double _gap = DsSpace.x8;
// Reserve for the unclassified tray (compact cap 112) plus the vertical gaps
// and the bottom FAB padding so the 2x2 board fills most of the viewport on
// tall screens.
const double _boardHeightReserve = 232;
const double _trayMaxHeight = 112;

class MatrixBoardField {
  const MatrixBoardField({
    required this.id,
    required this.title,
    required this.tasks,
  });

  final String id;
  final String title;
  final List<Task> tasks;
}

/// Priority value stored for a field id: p1 maps to 4 and p4 to 1.
int _dropPriority(String fieldId) => switch (fieldId) {
  'p1' => 4,
  'p2' => 3,
  'p3' => 2,
  'p4' => 1,
  _ => 0,
};

class MatrixBoard extends StatelessWidget {
  const MatrixBoard({
    super.key,
    required this.fields,
    required this.unclassified,
    required this.mode,
  });

  final List<MatrixBoardField> fields;
  final List<Task> unclassified;
  final MatrixMode mode;

  bool get _dragEnabled => mode == MatrixMode.priority;

  Widget _field(int index) => _MatrixField(
    key: ValueKey(fields[index].id),
    fields[index],
    dragEnabled: _dragEnabled,
    dropPriority: _dropPriority(fields[index].id),
  );

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Taller quadrants: derive height from the viewport so the 2x2 board
          // fills most of the screen; clamped for small/large screens.
          final cellHeight = ((constraints.maxHeight - _boardHeightReserve) / 2)
              .clamp(160.0, 520.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: cellHeight * 2 + _gap,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _field(0)),
                            const SizedBox(width: _gap),
                            Expanded(child: _field(1)),
                          ],
                        ),
                      ),
                      const SizedBox(height: _gap),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _field(2)),
                            const SizedBox(width: _gap),
                            Expanded(child: _field(3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DsSpace.x12),
                _UnclassifiedTray(
                  key: ValueKey('matrix-unclassified-${mode.name}'),
                  tasks: unclassified,
                  dragEnabled: _dragEnabled,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Flat card shell shared by the quadrants and the tray. A transparent 2px
/// ring keeps the drop hover state from shifting layout.
class _MatrixSurface extends StatelessWidget {
  const _MatrixSurface({
    super.key,
    required this.child,
    required this.hovering,
    this.constraints,
  });

  final Widget child;
  final bool hovering;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget card = AnimatedContainer(
      duration: DsMotion.fast,
      curve: DsMotion.standard,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DsRadius.r16),
        border: Border.all(
          color: hovering ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: AppSurface(
        tonal: true,
        padding: const EdgeInsets.fromLTRB(
          DsSpace.x12,
          DsSpace.x8,
          DsSpace.x12,
          DsSpace.x8,
        ),
        child: child,
      ),
    );
    // Height caps sit outside the implicit animation: tweening a constraints
    // range from unbounded to bounded would leave the inner list unconstrained
    // for a frame when the tray becomes populated.
    final constraints = this.constraints;
    if (constraints != null) {
      card = ConstrainedBox(constraints: constraints, child: card);
    }
    return card;
  }
}

class _FieldHeader extends StatelessWidget {
  const _FieldHeader({required this.title, required this.count, this.countKey});

  final String title;
  final int count;
  final Key? countKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: DsSpace.x8),
        Text(
          '$count',
          key: countKey,
          style: DsType.numeric(
            (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
