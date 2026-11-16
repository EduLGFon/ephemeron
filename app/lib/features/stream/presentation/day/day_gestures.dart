import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../engine/stream_time_viewport.dart';

/// Gesture wrapper for the day canvas: vertical pan, pinch zoom anchored on
/// the focal point, snapping to zoom presets, momentum fling, plus
/// wheel/trackpad scroll and Ctrl/Meta+scroll zoom.
class DayGestureRegion extends StatefulWidget {
  const DayGestureRegion({
    super.key,
    required this.viewport,
    required this.child,
    this.onGestureEnd,
    this.snapThreshold = 0.12,
  });

  final StreamTimeViewport viewport;
  final Widget child;
  final VoidCallback? onGestureEnd;
  final double snapThreshold;

  @override
  State<DayGestureRegion> createState() => _DayGestureRegionState();
}

class _DayGestureRegionState extends State<DayGestureRegion>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _dragStartOffset = 0;
  double _dragStartMpp = 0;
  Offset _dragStartFocal = Offset.zero;
  double _velocity = 0;
  int _lastTickMs = 0;
  bool _momentum = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final now = elapsed.inMilliseconds;
    if (_lastTickMs == 0) {
      _lastTickMs = now;
      return;
    }
    final dt = (now - _lastTickMs) / 1000.0;
    _lastTickMs = now;
    if (!_momentum) return;
    if (_velocity.abs() < 5) {
      _momentum = false;
      _velocity = 0;
      widget.onGestureEnd?.call();
      return;
    }
    widget.viewport.panBy(-_velocity * dt);
    _velocity *= pow(0.9, dt * 60).toDouble();
  }

  void _onScaleStart(ScaleStartDetails d) {
    _dragStartOffset = widget.viewport.offsetPx;
    _dragStartMpp = widget.viewport.minutesPerPixel;
    _dragStartFocal = d.focalPoint;
    _momentum = false;
    _velocity = 0;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final focal = d.focalPoint;
    if (d.scale == 1.0) {
      final delta = focal.dy - _dragStartFocal.dy;
      widget.viewport.setOffset(_dragStartOffset - delta, notify: false);
      return;
    }
    final newMpp = (_dragStartMpp / d.scale).clamp(
      StreamTimeViewport.hourMinutesPerPixel,
      StreamTimeViewport.dayMinutesPerPixel,
    );
    final focalTimeMs =
        widget.viewport.baseEpochMs +
        (_dragStartOffset + _dragStartFocal.dy) * _dragStartMpp * 60000.0;
    final newOffset =
        (focalTimeMs - widget.viewport.baseEpochMs) / (newMpp * 60000.0) -
        focal.dy;
    widget.viewport.setZoom(newMpp, notify: false);
    widget.viewport.setOffset(newOffset, notify: false);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    // Snap to nearest preset if close.
    final mpp = widget.viewport.minutesPerPixel;
    for (final p in StreamZoomPreset.values) {
      final target = StreamTimeViewport.minutesPerPixelFor(p);
      final dist = (mpp - target).abs() / target;
      if (dist <= widget.snapThreshold) {
        widget.viewport.setZoomPreset(p, focalPx: null);
        break;
      }
    }
    _velocity = d.velocity.pixelsPerSecond.dy;
    if (_velocity.abs() > 50) _momentum = true;
    widget.onGestureEnd?.call();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final zooming =
          keys.contains(LogicalKeyboardKey.controlLeft) ||
          keys.contains(LogicalKeyboardKey.controlRight) ||
          keys.contains(LogicalKeyboardKey.metaLeft) ||
          keys.contains(LogicalKeyboardKey.metaRight);
      if (zooming) {
        final delta = event.scrollDelta.dy;
        final factor = delta > 0 ? 1.1 : 0.9;
        widget.viewport.setZoom(
          widget.viewport.minutesPerPixel * factor,
          focalPx: event.localPosition.dy,
        );
        widget.onGestureEnd?.call();
      } else {
        widget.viewport.panBy(event.scrollDelta.dy);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: widget.child,
      ),
    );
  }
}
