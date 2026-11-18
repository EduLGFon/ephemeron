// Composed by the stream surface overlay unit.
// Composition widget binding [DayMarkGestures] to [DragMarkOverlay] through a
// [DragPreviewData] notifier, so the overlay follows a mark drag without
// rebuilding the stream below.

import 'package:material_ui/material_ui.dart';

import 'package:ephemeron/features/stream/application/stream_day_mark.dart';
import 'package:ephemeron/features/stream/engine/stream_mark_layout.dart';
import 'package:ephemeron/features/stream/engine/stream_time_viewport.dart';
import 'package:ephemeron/features/stream/presentation/gestures/day_mark_gestures.dart';
import 'package:ephemeron/features/stream/presentation/gestures/drag_mark_overlay.dart';
import 'package:ephemeron/features/stream/presentation/platform/stream_platform_capabilities.dart';

class DayMarkGestureLayer extends StatefulWidget {
  const DayMarkGestureLayer({
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
    this.onMarkTap,
    this.snapMinutes,
    this.swipeThresholdDp = 56.0,
    this.minBlockMinutes = 15,
    this.moveThresholdDp = 4.0,
    this.edgeMarginDp,
    this.dragPreview,
    this.timeFormatter,
    this.formatTime,
    this.overlayWidth,
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
  final ValueChanged<String>? onMarkTap;
  final int? snapMinutes;
  final double swipeThresholdDp;
  final int minBlockMinutes;
  final double moveThresholdDp;
  final double? edgeMarginDp;
  final ValueNotifier<DragPreviewData?>? dragPreview;
  final String Function(int epochMs)? timeFormatter;
  final String Function(int epochMs)? formatTime;
  final double? overlayWidth;

  @override
  State<DayMarkGestureLayer> createState() => _DayMarkGestureLayerState();
}

class _DayMarkGestureLayerState extends State<DayMarkGestureLayer> {
  ValueNotifier<DragPreviewData?>? _ownedNotifier;

  ValueNotifier<DragPreviewData?> get _notifier =>
      widget.dragPreview ??
      (_ownedNotifier ??= ValueNotifier<DragPreviewData?>(null));

  @override
  void dispose() {
    _ownedNotifier?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DayMarkGestures(
          viewport: widget.viewport,
          marks: widget.marks,
          markLayouts: widget.markLayouts,
          capabilities: widget.capabilities,
          onSwipeDone: widget.onSwipeDone,
          onSwipePush: widget.onSwipePush,
          onMoveMark: widget.onMoveMark,
          onMoveMarkEnd: widget.onMoveMarkEnd,
          onCreateBlock: widget.onCreateBlock,
          onMarkTap: widget.onMarkTap,
          snapMinutes: widget.snapMinutes,
          swipeThresholdDp: widget.swipeThresholdDp,
          minBlockMinutes: widget.minBlockMinutes,
          moveThresholdDp: widget.moveThresholdDp,
          edgeMarginDp: widget.edgeMarginDp,
          dragPreview: _notifier,
          timeFormatter: widget.timeFormatter,
          formatTime: widget.formatTime,
          child: widget.child,
        ),
        ValueListenableBuilder<DragPreviewData?>(
          valueListenable: _notifier,
          builder: (context, data, _) {
            if (data == null) return const SizedBox.shrink();
            return DragMarkOverlay(
              title: data.label,
              timeLabel: data.timeLabel,
              offset: data.localPosition,
              width: widget.overlayWidth,
            );
          },
        ),
      ],
    );
  }
}
