import 'package:flutter/foundation.dart';

/// Single source of truth for the stream viewport.
///
/// Holds scroll offset (pixels), zoom (ms per pixel) and a coarse level.
/// Gestures mutate it directly; listeners (painter, ticker) react.
class TimeViewport extends ChangeNotifier {
  TimeViewport({
    required this.minMsPerPixel,
    required this.maxMsPerPixel,
    required this.baseEpochMs,
  });

  final double minMsPerPixel;
  final double maxMsPerPixel;
  final int baseEpochMs;

  double _offsetPx = 0;
  double _msPerPixel = 60000; // 1 minute per pixel default
  int _level = 0;
  double _viewportHeight = 0;

  double get offsetPx => _offsetPx;
  double get msPerPixel => _msPerPixel;
  int get level => _level;
  double get viewportHeight => _viewportHeight;

  void setViewportHeight(double h) {
    if (h == _viewportHeight) return;
    _viewportHeight = h;
    notifyListeners();
  }

  void setOffset(double v, {bool notify = true}) {
    final maxOffset = _maxOffset();
    _offsetPx = v.clamp(0.0, maxOffset);
    if (notify) notifyListeners();
  }

  void setZoom(double msPerPixel, {double? focalPx, bool notify = true}) {
    final clamped = msPerPixel.clamp(minMsPerPixel, maxMsPerPixel);
    if (focalPx != null) {
      // Keep the time under the focal pixel stable across the zoom change.
      final focalTime = baseEpochMs + (_offsetPx + focalPx) * _msPerPixel;
      _msPerPixel = clamped;
      _offsetPx = (focalTime - baseEpochMs) / clamped - focalPx;
    } else {
      _msPerPixel = clamped;
    }
    _offsetPx = _offsetPx.clamp(0.0, _maxOffset());
    _level = _levelFor(_msPerPixel);
    if (notify) notifyListeners();
  }

  void panBy(double deltaPx) {
    setOffset(_offsetPx - deltaPx);
  }

  double _maxOffset() {
    // Allow scrolling one viewport beyond the last mark region; computed
    // loosely so the user can reach the end comfortably.
    const totalMs = 365 * 24 * 60 * 60 * 1000;
    final totalPx = totalMs / _msPerPixel;
    final max = totalPx - _viewportHeight;
    return max < 0 ? 0 : max;
  }

  int _levelFor(double msPerPixel) {
    // Coarse levels: 0 day, 1 week-ish, 2 month, 3 year.
    if (msPerPixel < 5 * 60 * 1000) return 0;
    if (msPerPixel < 60 * 60 * 1000) return 1;
    if (msPerPixel < 6 * 60 * 60 * 1000) return 2;
    return 3;
  }

  // Helpers for painters.
  double timeToPx(int epochMs) =>
      (epochMs - baseEpochMs) / _msPerPixel - _offsetPx;
  int pxToTime(double px) =>
      baseEpochMs + ((px + _offsetPx) * _msPerPixel).round();
}
