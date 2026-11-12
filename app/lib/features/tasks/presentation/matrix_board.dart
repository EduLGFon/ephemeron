// Responsive 2x2 matrix board: four equal fields plus a separate tray for
// tasks that no field claims. Task rows open the editor on tap. In priority
// mode rows can be long-pressed and dragged between fields and the tray, and
// every row carries a circular complete checkbox.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/tasks/eisenhower.dart';
import '../application/tasks_providers.dart';
import '../../../domain/sources/microsoft_source.dart';
import 'matrix_task_row.dart';

part 'matrix_board/drop_zone.dart';
part 'matrix_board/field.dart';
part 'matrix_board/tray.dart';

const double _pagePadding = 12;
const double _gap = 8;
// Reserve for the unclassified tray (140) plus vertical gaps and the bottom
// FAB padding so the 2x2 board fills most of the viewport on tall screens.
const double _boardHeightReserve = 260;

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

ShapeBorder? _dropShape(ThemeData theme, bool hovering) => hovering
    ? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.primary, width: 2),
      )
    : null;

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
              .clamp(160.0, 420.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              _pagePadding,
              _pagePadding,
              _pagePadding,
              88,
            ),
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
                const SizedBox(height: 12),
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
