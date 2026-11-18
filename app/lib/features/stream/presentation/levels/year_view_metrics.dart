part of 'year_view_layout.dart';

class _YearMetrics {
  const _YearMetrics({
    required this.cellSize,
    required this.blockWidth,
    required this.gridWidth,
    required this.headerHeight,
    required this.blockHeight,
    required this.firstRow,
    required this.rowCount,
  });

  factory _YearMetrics.compute({
    required double width,
    required double textScale,
    required int columns,
    required List<int> visible,
  }) {
    final available = math.max(
      0.0,
      width - 2 * _outerPadding - (columns - 1) * _columnGap,
    );
    final blockWidth = math.max(1.0, available / columns);
    final gridWidth = math.max(1.0, blockWidth - 2 * _innerPadding);
    final cellSize = gridWidth / 7;
    final headerHeight = math.max(1.0, _headerTextHeight * textScale);
    final firstRow = visible.isEmpty ? 0 : (visible.first - 1) ~/ columns;
    final lastRow = visible.isEmpty ? 0 : (visible.last - 1) ~/ columns;
    return _YearMetrics(
      cellSize: cellSize,
      blockWidth: blockWidth,
      gridWidth: gridWidth,
      headerHeight: headerHeight,
      blockHeight:
          2 * _innerPadding +
          headerHeight +
          _headerGap +
          cellSize * _maxWeekRows,
      firstRow: firstRow,
      rowCount: visible.isEmpty ? 0 : lastRow - firstRow + 1,
    );
  }

  final double cellSize;
  final double blockWidth;
  final double gridWidth;
  final double headerHeight;
  final double blockHeight;
  final int firstRow;
  final int rowCount;

  double get height => rowCount == 0
      ? 0
      : 2 * _outerPadding + rowCount * blockHeight + (rowCount - 1) * _rowGap;
}
