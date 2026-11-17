// Gesture layer for the Stream day view.
//
// Wraps an existing canvas child and recognises swipe-to-complete/push and
// long-press-drag to move or create. Never starts a gesture within
// [edgeMarginDp] of the left/right edges. Vertical drags that are not mark
// gestures are left untouched so an outer DayGestureRegion can still scroll.
//
// Auto-scroll at top/bottom during a drag is a documented follow-up and is
// not implemented here.
//
// Undo is owned by the caller: this layer only reports actions via callbacks;
// the caller applies them optimistically and shows showUndoSnackBar.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/core/ui/app_feedback.dart';
import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/mark_hit_test.dart';
import 'package:ephemeron/features/stream/engine/stream_mark_layout.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/gestures/drag_mark_overlay.dart';
import 'package:ephemeron/features/stream/presentation/platform/stream_platform_capabilities.dart';

class DayMarkGestures extends StatefulWidget {
  const DayMarkGestures({
    super.key,
    required this.viewport,
    required this.marks,
    required this.markLayouts,
    required this.child,
    this.capabilities = PlatformCapabilities.defaults,
    this.onSwipeDone,
    this.onSwipePush,
    this.onMoveMark,
    this.onMoveMarkEnd,
    this.onCreateBlock,
    this.snapMinutes,
    this.swipeThresholdDp = 56.0,
    this.minBlockMinutes = 15,
    this.moveThresholdDp = 4.0,
    this.edgeMarginDp,
    this.dragPreview,
  });

  final StreamTimeViewport viewport;
  final List<StreamDayMark> marks;
  final List<MarkLayout> markLayouts;
  final Widget child;
  final PlatformCapabilities capabilities;
  final void Function(String id)? onSwipeDone;
  final void Function(String id)? onSwipePush;
  final void Function(String id, int newStartMs)? onMoveMark;
  final void Function(String id, int newStartMs)? onMoveMarkEnd;
  final void Function(int startMs, int endMs)? onCreateBlock;
  final int? snapMinutes;
  final double swipeThresholdDp;
  final int minBlockMinutes;
  final double moveThresholdDp;
  final double? edgeMarginDp;
  final ValueNotifier<DragPreviewData?>? dragPreview;

  @override
  State<DayMarkGestures> createState() => _DayMarkGesturesState();
}

class _DayMarkGesturesState extends State<DayMarkGestures> {
  Size _size = Size.zero;

  String? _swipeMarkId;
  double _swipeDx = 0;
  bool _swipeFired = false;

  String? _moveMarkId;
  int _originalStartMs = 0;
  int _grabOffsetMs = 0;
  double _pressY = 0;
  bool _movedBeyond = false;
  int _lastSnappedMs = -1;

  double _createStartY = 0;
  double _createCurrentY = 0;
  bool _creating = false;

  double get _margin =>
      widget.edgeMarginDp ?? widget.capabilities.edgeGestureMarginDp.toDouble();

  bool _inEdge(double x) => x < _margin || x > _size.width - _margin;

  String? _hitMark(double x, double y) {
    if (_inEdge(x)) return null;
    return hitTestMark(
      marks: widget.marks,
      layout: widget.markLayouts,
      viewport: widget.viewport,
      focalY: y,
      canvasWidth: _size.width,
      focalX: x,
      edgeMarginDp: 0,
    );
  }

  StreamDayMark? _markById(String id) {
    for (final m in widget.marks) {
      if (m.id == id) return m;
    }
    return null;
  }

  int _snapMinutes() {
    if (widget.snapMinutes != null) return widget.snapMinutes!;
    switch (widget.viewport.zoomPreset) {
      case StreamZoomPreset.hour:
        return 5;
      case StreamZoomPreset.day:
        return 15;
    }
  }

  int _snap(int ms) {
    final snapMs = _snapMinutes() * 60 * 1000;
    return ((ms + snapMs ~/ 2) ~/ snapMs) * snapMs;
  }

  void _onHorizStart(DragStartDetails d) {
    _swipeDx = 0;
    _swipeFired = false;
    final x = d.localPosition.dx;
    if (_inEdge(x)) {
      _swipeMarkId = null;
      return;
    }
    _swipeMarkId = _hitMark(x, d.localPosition.dy);
  }

  void _onHorizUpdate(DragUpdateDetails d) {
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

  void _onLongPressStart(LongPressStartDetails d) {
    final x = d.localPosition.dx;
    if (_inEdge(x)) {
      _moveMarkId = null;
      _creating = false;
      return;
    }
    final id = _hitMark(x, d.localPosition.dy);
    if (id != null) {
      _moveMarkId = id;
      final mark = _markById(id);
      final pressTime = widget.viewport.pxToTime(d.localPosition.dy);
      _originalStartMs = mark?.startMs ?? pressTime;
      _grabOffsetMs = pressTime - _originalStartMs;
      _pressY = d.localPosition.dy;
      _movedBeyond = false;
      _lastSnappedMs = -1;
    } else {
      _moveMarkId = null;
      _creating = true;
      _createStartY = d.localPosition.dy;
      _createCurrentY = d.localPosition.dy;
    }
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    if (_moveMarkId != null) {
      if ((d.localPosition.dy - _pressY).abs() >= widget.moveThresholdDp) {
        _movedBeyond = true;
      }
      final pressTime = widget.viewport.pxToTime(d.localPosition.dy);
      final newStart = _snap(pressTime - _grabOffsetMs);
      if (newStart != _lastSnappedMs) {
        _lastSnappedMs = newStart;
        if (_movedBeyond) AppFeedback.selection();
      }
      if (_movedBeyond || newStart != _originalStartMs) {
        widget.onMoveMark?.call(_moveMarkId!, newStart);
        final mark = _markById(_moveMarkId!);
        widget.dragPreview?.value = DragPreviewData(
          id: _moveMarkId!,
          globalPosition: d.globalPosition,
          label: mark?.title ?? '',
        );
      }
    } else if (_creating) {
      _createCurrentY = d.localPosition.dy;
    }
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    if (_moveMarkId != null) {
      final id = _moveMarkId!;
      if (_movedBeyond || _lastSnappedMs != _originalStartMs) {
        final snapped = _lastSnappedMs >= 0 ? _lastSnappedMs : _originalStartMs;
        if (snapped != _originalStartMs) {
          widget.onMoveMarkEnd?.call(id, snapped);
        }
      }
      widget.dragPreview?.value = null;
      _moveMarkId = null;
      _lastSnappedMs = -1;
    } else if (_creating) {
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onHorizStart,
          onHorizontalDragUpdate: _onHorizUpdate,
          onHorizontalDragEnd: _onHorizEnd,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMove,
          onLongPressEnd: _onLongPressEnd,
          child: widget.child,
        );
      },
    );
  }
}
