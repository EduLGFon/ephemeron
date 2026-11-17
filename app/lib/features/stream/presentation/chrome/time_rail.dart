import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import '../../design/stream_tokens.dart';

/// Left column showing hour labels for [hourCount] hours.
///
/// Labels are supplied either as [hourLabels] (a list aligned by index) or
/// via [hourLabelBuilder] (index -> label). Only the labels currently
/// visible for the given [hourHeight] and scroll offset are built, so a long
/// range stays cheap. The scroll offset may be a static [scrollOffset] or a
/// [scrollOffsetListenable] so only this rail repaints on scroll.
class TimeRail extends StatelessWidget {
  const TimeRail({
    super.key,
    this.hourCount,
    required this.hourHeight,
    this.hourLabels,
    this.hourLabelBuilder,
    this.scrollOffset = 0,
    this.scrollOffsetListenable,
    this.viewportHeight,
  });

  final int? hourCount;
  final double hourHeight;
  final List<String>? hourLabels;
  final String Function(int index)? hourLabelBuilder;
  final double scrollOffset;
  final ValueListenable<double>? scrollOffsetListenable;
  final double? viewportHeight;

  String _labelFor(int index) {
    if (hourLabels != null && index < hourLabels!.length) {
      return hourLabels![index];
    }
    if (hourLabelBuilder != null) return hourLabelBuilder!(index);
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (scrollOffsetListenable != null) {
      return ValueListenableBuilder<double>(
        valueListenable: scrollOffsetListenable!,
        builder: (context, offset, _) => _build(context, offset),
      );
    }
    return _build(context, scrollOffset);
  }

  Widget _build(BuildContext context, double offset) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vh = viewportHeight ?? constraints.maxHeight;
        var first = (offset / hourHeight).floor().toInt();
        final visibleCount = (vh / hourHeight).ceil() + 1;
        var last = first + visibleCount;
        if (hourCount != null) {
          if (first >= hourCount!) {
            first = hourCount!;
            last = hourCount!;
          } else {
            last = last.clamp(first, hourCount!);
          }
        }
        final children = <Widget>[];
        for (var i = first; i < last; i++) {
          children.add(
            PositionedDirectional(
              top: i * hourHeight - offset,
              start: 0,
              child: SizedBox(
                height: hourHeight,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _labelFor(i),
                    style: TextStyle(
                      fontSize: StreamTypeScale.xs,
                      fontWeight: FontWeight(StreamFontWeight.regular),
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          height: vh,
          child: Stack(clipBehavior: Clip.hardEdge, children: children),
        );
      },
    );
  }
}
