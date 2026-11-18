part of 'day_mark_gestures.dart';

extension _DayMarkGestureSwipe on _DayMarkGesturesState {
  void _onHorizStart(DragStartDetails d, Size size) {
    _swipeDx = 0;
    _swipeFired = false;
    final x = d.localPosition.dx;
    if (_inEdge(x, size)) {
      _swipeMarkId = null;
      return;
    }
    _swipeMarkId = _hitMark(x, d.localPosition.dy, size);
  }

  void _onHorizUpdate(DragUpdateDetails d, Size size) {
    if (_swipeMarkId == null || _swipeFired) return;
    _swipeDx += d.delta.dx;
  }

  void _onHorizEnd(DragEndDetails d) {
    final id = _swipeMarkId;
    _swipeMarkId = null;
    if (id == null || _swipeFired) {
      _swipeDx = 0;
      return;
    }
    if (_swipeDx >= widget.swipeThresholdDp) {
      _swipeFired = true;
      widget.onSwipeDone?.call(id);
      AppFeedback.success();
    } else if (_swipeDx <= -widget.swipeThresholdDp) {
      _swipeFired = true;
      widget.onSwipePush?.call(id);
      AppFeedback.tap();
    }
    _swipeDx = 0;
  }
}
