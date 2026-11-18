part of 'day_mark_gestures.dart';

// Tap-to-open arbitration.
//
// The tap shares the [GestureDetector] arena with the swipe and long-press
// recognizers. A horizontal drag or long-press that activates wins the arena
// and rejects the tap, so onMarkTap never follows a swipe, move or create.
// The tap recognizer is only registered when [DayMarkGestures.onMarkTap] is
// set, keeping the arena unchanged for callers that do not open marks.
//
// Taps reuse [hitTestMark] with no edge margin: the 24 dp edge restriction is
// for action gestures only. Overlapping marks resolve to the last painted
// column containing the point, matching the painter's order.

extension _DayMarkGestureTap on _DayMarkGesturesState {
  void _onTapUp(TapUpDetails d, Size size) {
    final onMarkTap = widget.onMarkTap;
    if (onMarkTap == null) return;
    final id = _hitMark(
      d.localPosition.dx,
      d.localPosition.dy,
      size,
      allowEdges: true,
    );
    if (id != null) onMarkTap(id);
  }
}
