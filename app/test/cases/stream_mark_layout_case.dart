import 'package:ephemeron/features/stream/engine/stream_mark_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no overlap -> one column', () {
    final marks = [
      const MarkInterval(startMs: 0, endMs: 1000, id: 'a'),
      const MarkInterval(
        startMs: 10 * 60 * 1000,
        endMs: 11 * 60 * 1000,
        id: 'b',
      ),
    ];
    final r = layoutMarkColumns(marks);
    expect(r[0].column, 0);
    expect(r[0].columnCount, 1);
    expect(r[1].column, 0);
    expect(r[1].columnCount, 1);
  });

  test('two overlapping -> two columns', () {
    final marks = [
      const MarkInterval(startMs: 0, endMs: 2000, id: 'a'),
      const MarkInterval(startMs: 1000, endMs: 3000, id: 'b'),
    ];
    final r = layoutMarkColumns(marks);
    expect(r[0].columnCount, 2);
    expect(r[1].columnCount, 2);
    expect({r[0].column, r[1].column}, {0, 1});
  });

  test('three nested -> three columns', () {
    final marks = [
      const MarkInterval(startMs: 0, endMs: 3000, id: 'a'),
      const MarkInterval(startMs: 500, endMs: 2500, id: 'b'),
      const MarkInterval(startMs: 1000, endMs: 2000, id: 'c'),
    ];
    final r = layoutMarkColumns(marks);
    expect(r.every((x) => x.columnCount == 3), true);
  });

  test('zero-length marks use min visual height', () {
    final marks = [
      const MarkInterval(startMs: 0, endMs: 0, id: 'a'),
      const MarkInterval(startMs: 0, endMs: 0, id: 'b'),
    ];
    final r = layoutMarkColumns(marks);
    expect(r[0].columnCount, 2);
  });

  test('determinism', () {
    final marks = [
      const MarkInterval(startMs: 0, endMs: 2000, id: 'a'),
      const MarkInterval(startMs: 1000, endMs: 3000, id: 'b'),
    ];
    final r1 = layoutMarkColumns(marks);
    final r2 = layoutMarkColumns(marks);
    expect(r1, r2);
  });

  test('sorted output stability', () {
    final marks = [
      const MarkInterval(startMs: 1000, endMs: 3000, id: 'b'),
      const MarkInterval(startMs: 0, endMs: 2000, id: 'a'),
    ];
    final r = layoutMarkColumns(marks);
    // first input (b) overlaps a -> 2 columns
    expect(r[0].columnCount, 2);
    expect(r[1].columnCount, 2);
  });
}
