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

part 'day_mark_gesture_swipe.dart';
part 'day_mark_gesture_move.dart';
part 'day_mark_gesture_create.dart';

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
  String? _swipeMarkId;
  double _swipeDx = 0;
  bool _swipeFired = false;

  String? _moveMarkId;
  StreamDayMark? _moveMark;
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

  bool _inEdge(double x, Size size) => x < _margin || x > size.width - _margin;

  String? _hitMark(double x, double y, Size size) {
    if (_inEdge(x, size)) return null;
    return hitTestMark(
      marks: widget.marks,
      layout: widget.markLayouts,
      viewport: widget.viewport,
      focalY: y,
      canvasWidth: size.width,
      focalX: x,
      edgeMarginDp: 0,
    );
  }

  StreamDayMark? _moveMarkFor(String id) {
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (d) => _onHorizStart(d, size),
          onHorizontalDragUpdate: (d) => _onHorizUpdate(d, size),
          onHorizontalDragEnd: _onHorizEnd,
          onLongPressStart: (d) => _onLongPressStart(d, size),
          onLongPressMoveUpdate: (d) => _onLongPressMove(d, size),
          onLongPressEnd: _onLongPressEnd,
          child: widget.child,
        );
      },
    );
  }
}
