import 'package:ephemeron/features/stream/engine/mark_culler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cullMarks basic', () {
    final starts = <int>[0, 100, 200, 300];
    final ends = <int>[50, 150, 250, 350];
    final r = cullMarks(starts, ends, 100, 200);
    expect(r.start, 1);
    expect(r.end, 3); // marks at 100,200
  });

  test('cullMarks empty', () {
    final r = cullMarks(<int>[], <int>[], 0, 10);
    expect(r.start, 0);
    expect(r.end, 0);
  });

  test('cullMarks long mark starting earlier included', () {
    final starts = <int>[0, 100];
    final ends = <int>[500, 150];
    final r = cullMarks(starts, ends, 200, 300);
    expect(r.start, 0);
    expect(r.end, 2);
  });
}
