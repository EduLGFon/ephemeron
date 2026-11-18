import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../engine/stream_time_viewport.dart';

/// Gesture wrapper for the day canvas.
///
/// Zoom is continuous for now. Semantic-level snapping to zoom presets
/// arrives in a later phase.
class DayGestureRegion extends StatefulWidget {
  const DayGestureRegion({
    super.key,
    required this.viewport,
    required this.child,
    this.onGestureEnd,
  });

  final StreamTimeViewport viewport;
  final Widget child;
  final VoidCallback? onGestureEnd;

  @override
  State<DayGestureRegion> createState() => DayGestureRegionState();
}

class DayGestureRegionState extends State<DayGestureRegion>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _dragStartOffset = 0;
  double _dragStartMpp = 0;
  Offset _dragStartFocal = Offset.zero;
  double _velocity = 0;
  int? _lastTickMs;
  bool _momentum = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    if (_ticker.isActive) _ticker.stop();
    _ticker.dispose();
    super.dispose();
  }

  bool get tickerIsActive => _ticker.isActive;

  void _onTick(Duration elapsed) {
    final now = elapsed.inMilliseconds;
    if (_lastTickMs == null) {
      _lastTickMs = now;
      return;
    }
    final dt = (now - _lastTickMs!) / 1000.0;
    _lastTickMs = now;
    if (!_momentum) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    widget.viewport.panBy(_velocity * dt);
    _velocity *= pow(0.9, dt * 60).toDouble();
    if (_velocity.abs() < 5) {
      _momentum = false;
      _velocity = 0;
      if (_ticker.isActive) _ticker.stop();
      widget.onGestureEnd?.call();
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _dragStartOffset = widget.viewport.offsetPx;
    _dragStartMpp = widget.viewport.minutesPerPixel;
    _dragStartFocal = d.localFocalPoint;
    _momentum = false;
    _velocity = 0;
    _lastTickMs = null;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final focal = d.localFocalPoint;
    if (d.scale == 1.0) {
      final delta = focal.dy - _dragStartFocal.dy;
      widget.viewport.setOffset(_dragStartOffset - delta);
      return;
    }
    final newMpp = (_dragStartMpp / d.scale).clamp(
      StreamTimeViewport.hourMinutesPerPixel,
      StreamTimeViewport.dayMinutesPerPixel,
    );
    widget.viewport.setZoom(newMpp, focalPx: _dragStartFocal.dy);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _velocity = d.velocity.pixelsPerSecond.dy;
    if (_velocity.abs() > 50) {
      _momentum = true;
      if (!_ticker.isActive) _ticker.start();
    } else {
      widget.onGestureEnd?.call();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      if (e is! PointerScrollEvent) return;
      final pe = e;
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final zooming =
          keys.contains(LogicalKeyboardKey.controlLeft) ||
          keys.contains(LogicalKeyboardKey.controlRight) ||
          keys.contains(LogicalKeyboardKey.metaLeft) ||
          keys.contains(LogicalKeyboardKey.metaRight);
      if (zooming) {
        final factor = pe.scrollDelta.dy > 0 ? 1.1 : 0.9;
        widget.viewport.setZoom(
          widget.viewport.minutesPerPixel * factor,
          focalPx: pe.localPosition.dy,
        );
        // Wheel zoom is discrete; no onGestureEnd to avoid per-event spam.
      } else {
        // Scroll down (dy > 0) moves later in time.
        widget.viewport.setOffset(widget.viewport.offsetPx + pe.scrollDelta.dy);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: widget.child,
      ),
    );
  }
}
