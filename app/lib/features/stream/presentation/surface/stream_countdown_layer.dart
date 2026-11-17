// Countdown landmarks for the Stream day surface.
//
// A countdown whose target day maps inside the visible day body renders as a
// hairline at that position; the rest are pinned as edge chips ordered by
// proximity to the viewport. Presentation only: the host injects labels and
// actions. Only this subtree listens to the day controller and its scroll
// offset, so the day canvas is not rebuilt on scroll.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/stream_ambient.dart';
import '../../design/stream_tokens.dart';
import '../countdowns/countdown_edge_chips.dart';
import '../countdowns/countdown_landmark.dart';
import '../countdowns/countdown_landmark_item.dart';
import '../countdowns/countdown_math.dart';
import '../stream_day_controller.dart';

/// Width of the time rail left of the marks area (matches the day body view).
const double _railWidth = 56;

/// Scrubber column right of the marks area (matches the day body view).
const double _scrubberWidth = 48.0 + StreamSpacing.x6;

/// Landmarks this close to the viewport still render in place.
const double _viewportMargin = 8;

const double _edgeInset = StreamSpacing.x3;

/// Builds the caller-owned label for [item] given its whole-day distance.
typedef CountdownLabelBuilder = String Function(
  CountdownLandmarkItem item,
  int days,
);

typedef _Placed = ({
  CountdownLandmarkItem item,
  double y,
  int days,
  String label,
});

double _distanceTo(_Placed placed, double viewportHeight) =>
    placed.y < 0 ? -placed.y : placed.y - viewportHeight;

/// Overlay of countdown landmarks and out-of-view edge chips.
class StreamCountdownLayer extends ConsumerWidget {
  const StreamCountdownLayer({
    super.key,
    required this.controller,
    required this.day,
    required this.now,
    required this.labelBuilder,
    required this.onTap,
    required this.onShowAll,
    required this.edge,
  });

  final StreamDayBodyController controller;
  final DateTime day;
  final DateTime now;
  final CountdownLabelBuilder labelBuilder;
  final void Function(String id) onTap;
  final VoidCallback onShowAll;
  final CountdownEdge edge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(streamCountdownLandmarkItemsProvider).value ??
        const <CountdownLandmarkItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.scrollListenable]),
      builder: (context, _) => _buildOverlay(items),
    );
  }

  Widget _buildOverlay(List<CountdownLandmarkItem> items) {
    final height = controller.viewport?.viewportHeight ?? 0;
    if (height <= 0) return const SizedBox.shrink();
    final inView = <_Placed>[];
    final outOfView = <_Placed>[];
    for (final item in items) {
      final days = daysUntil(item, now);
      // Position is anchored to the rendered day; the label to now. Both share
      // target validity, so a null either way means "skip".
      final dayOffset = daysUntil(item, day);
      if (days == null || dayOffset == null) continue;
      final target = DateTime(day.year, day.month, day.day + dayOffset);
      final y = controller.timeToY(target);
      if (y == null) continue;
      final placed = (
        item: item,
        y: y,
        days: days,
        label: labelBuilder(item, days),
      );
      if (y >= -_viewportMargin && y <= height + _viewportMargin) {
        inView.add(placed);
      } else {
        outOfView.add(placed);
      }
    }
    if (inView.isEmpty && outOfView.isEmpty) return const SizedBox.shrink();
    outOfView.sort(
      (a, b) => _distanceTo(a, height).compareTo(_distanceTo(b, height)),
    );
    final labels = <String, String>{
      for (final entry in outOfView) entry.item.id: entry.label,
    };
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final entry in inView)
          Positioned(
            top: entry.y,
            left: _railWidth,
            right: _scrubberWidth,
            child: CountdownLandmark(
              id: entry.item.id,
              title: entry.item.title,
              label: entry.label,
              days: entry.days,
              colorArgb: entry.item.colorArgb,
              onTap: onTap,
            ),
          ),
        if (outOfView.isNotEmpty)
          Positioned(
            top: edge == CountdownEdge.top ? _edgeInset : null,
            bottom: edge == CountdownEdge.bottom ? _edgeInset : null,
            left: _railWidth,
            right: _scrubberWidth,
            child: CountdownEdgeChips(
              items: [for (final entry in outOfView) entry.item],
              edge: edge,
              labelBuilder: (item) => labels[item.id] ?? item.title,
              onTap: onTap,
              onShowAll: onShowAll,
            ),
          ),
      ],
    );
  }
}
