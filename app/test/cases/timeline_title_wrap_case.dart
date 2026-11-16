import 'package:ephemeron/features/calendar/presentation/timeline/timeline_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = TextStyle(fontSize: 12, height: 1.2);

  test('short 30-minute block allows a single line', () {
    final lines = timelineTitleMaxLines(
      availableHeight: 28,
      style: style,
      textScaler: TextScaler.noScaling,
    );
    expect(lines, 1);
  });

  test('tall 4-hour block allows many lines', () {
    final lines = timelineTitleMaxLines(
      availableHeight: 224,
      style: style,
      textScaler: TextScaler.noScaling,
    );
    expect(lines, greaterThan(10));
  });

  test('text scaling reduces the number of lines', () {
    final normal = timelineTitleMaxLines(
      availableHeight: 224,
      style: style,
      textScaler: TextScaler.noScaling,
    );
    final scaled = timelineTitleMaxLines(
      availableHeight: 224,
      style: style,
      textScaler: const TextScaler.linear(2.0),
    );
    expect(scaled, lessThan(normal));
  });

  test('source label reservation reduces available title lines', () {
    final withoutLabel = timelineTitleMaxLines(
      availableHeight: 120,
      style: style,
      textScaler: TextScaler.noScaling,
      reserveSourceLabel: false,
    );
    final withLabel = timelineTitleMaxLines(
      availableHeight: 120,
      style: style,
      textScaler: TextScaler.noScaling,
      reserveSourceLabel: true,
    );
    expect(withLabel, lessThanOrEqualTo(withoutLabel));
  });

  test('never returns less than one line', () {
    final lines = timelineTitleMaxLines(
      availableHeight: 1,
      style: style,
      textScaler: TextScaler.noScaling,
    );
    expect(lines, 1);
  });
}
