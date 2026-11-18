import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../engine/time_viewport.dart';
import '../data/fake_marks.dart';
import 'stream_painter.dart';

class StreamSpikeScreen extends StatefulWidget {
  const StreamSpikeScreen({super.key});

  @override
  State<StreamSpikeScreen> createState() => _StreamSpikeScreenState();
}

class _StreamSpikeScreenState extends State<StreamSpikeScreen>
    with SingleTickerProviderStateMixin {
  late final List<StreamMark> _marks;
  late final List<int> _starts;
  late final List<int> _ends;
  late final TimeViewport _viewport;
  late final Ticker _ticker;

  double _dragStartOffset = 0;
  double _dragStartMsPerPixel = 0;
  Offset _dragStartFocal = Offset.zero;
  double _velocity = 0;
  int _lastTickMs = 0;
  bool _momentum = false;

  static const double _minZoom = 1000; // ms per pixel
  static const double _maxZoom = 3600000; // 1 hour per pixel

  @override
  void initState() {
    super.initState();
    _marks = generateFakeMarks();
    _starts = _marks.map((m) => m.startMs).toList(growable: false);
    _ends = _marks.map((m) => m.endMs).toList(growable: false);
    _viewport = TimeViewport(
      minMsPerPixel: _minZoom,
      maxMsPerPixel: _maxZoom,
      baseEpochMs: _marks.first.startMs,
    );
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _viewport.dispose();
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
      return;
    }
    _viewport.panBy(-_velocity * dt);
    _velocity *= pow(0.9, dt * 60).toDouble();
  }

  void _onScaleStart(ScaleStartDetails d) {
    _dragStartOffset = _viewport.offsetPx;
    _dragStartMsPerPixel = _viewport.msPerPixel;
    _dragStartFocal = d.focalPoint;
    _momentum = false;
    _velocity = 0;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final focal = d.focalPoint;
    if (d.scale == 1.0) {
      // Pure pan.
      final delta = focal.dy - _dragStartFocal.dy;
      _viewport.setOffset(_dragStartOffset - delta);
      return;
    }
    final newMsPerPixel = (_dragStartMsPerPixel / d.scale).clamp(
      _minZoom,
      _maxZoom,
    );
    final focalTime =
        _viewport.baseEpochMs +
        (_dragStartOffset + _dragStartFocal.dy) * _dragStartMsPerPixel;
    final newOffset =
        (focalTime - _viewport.baseEpochMs) / newMsPerPixel - focal.dy;
    _viewport.setZoom(newMsPerPixel, notify: false);
    _viewport.setOffset(newOffset);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _velocity = d.velocity.pixelsPerSecond.dy;
    if (_velocity.abs() > 50) _momentum = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stream spike')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewport.setViewportHeight(constraints.maxHeight);
          return GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: StreamPainter(
                  viewport: _viewport,
                  marks: _marks,
                  starts: _starts,
                  ends: _ends,
                ),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
          );
        },
      ),
    );
  }
}
