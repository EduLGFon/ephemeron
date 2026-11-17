part of 'day_mark_gestures.dart';

extension _DayMarkGestureCreate on _DayMarkGesturesState {
  void _handleCreateEnd() {
    final t0 = widget.viewport.pxToTime(_createStartY);
    final t1 = widget.viewport.pxToTime(_createCurrentY);
    var s = math.min(t0, t1);
    var e = math.max(t0, t1);
    final minMs = widget.minBlockMinutes * 60 * 1000;
    if (e - s < minMs) e = s + minMs;
    widget.onCreateBlock?.call(s, e);
    AppFeedback.success();
    _creating = false;
  }
}
