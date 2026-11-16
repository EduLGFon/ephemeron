import 'package:ephemeron/features/calendar/presentation/timeline/timeline_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = TextStyle(fontSize: 12, height: 1.2);

  test('short 30-minute block allows a single line', () {
    final lines = timelineTitleMaxLines(
      contentHeight: 28,
      style: style,
      textScaler: TextScaler.noScaling,
    );
    expect(lines, 1);
  });

  test('tall 4-hour block allows many lines', () {
    final lines = timelineTitleMaxLines(
      contentHeight: 224,
      style: style,
      textScaler: TextScaler.noScaling,
    );
    expect(lines, greaterThan(10));
  });

  test('text scaling reduces the number of lines', () {
    final normal = timelineTitleMaxLines(
      contentHeight: 224,
      style: style,
      textScaler: TextScaler.noScaling,
    );
    final scaled = timelineTitleMaxLines(
      contentHeight: 224,
      style: style,
      textScaler: const TextScaler.linear(2.0),
    );
    expect(scaled, lessThan(normal));
  });

  test('source label reservation reduces available title lines', () {
    final withoutLabel = timelineTitleMaxLines(
      contentHeight: 120,
      style: style,
      textScaler: TextScaler.noScaling,
      reserveSourceLabel: false,
    );
    final withLabel = timelineTitleMaxLines(
      contentHeight: 120,
      style: style,
      textScaler: TextScaler.noScaling,
      reserveSourceLabel: true,
    );
    expect(withLabel, lessThanOrEqualTo(withoutLabel));
  });

  test('never returns less than one line', () {
    final lines = timelineTitleMaxLines(
      contentHeight: 1,
      style: style,
      textScaler: TextScaler.noScaling,
    );
    expect(lines, 1);
  });

  test('non-finite or invalid measurements fall back to one line', () {
    expect(
      timelineTitleMaxLines(
        contentHeight: double.infinity,
        style: style,
        textScaler: TextScaler.noScaling,
      ),
      1,
    );
    expect(
      timelineTitleMaxLines(
        contentHeight: double.nan,
        style: style,
        textScaler: TextScaler.noScaling,
      ),
      1,
    );
    expect(
      timelineTitleMaxLines(
        contentHeight: 224,
        style: const TextStyle(fontSize: double.infinity),
        textScaler: TextScaler.noScaling,
      ),
      1,
    );
  });

  test('source label is hidden when it would steal the last title line', () {
    // 48 px / 18 px lines leaves two title lines, but reserving the label
    // drops it to one, so the label must stay hidden.
    const largeStyle = TextStyle(fontSize: 18, height: 1);
    expect(
      timelineShowSourceLabel(
        contentHeight: 48,
        style: largeStyle,
        textScaler: TextScaler.noScaling,
      ),
      isFalse,
    );
    expect(
      timelineShowSourceLabel(
        contentHeight: 224,
        style: largeStyle,
        textScaler: TextScaler.noScaling,
      ),
      isTrue,
    );
  });
}
