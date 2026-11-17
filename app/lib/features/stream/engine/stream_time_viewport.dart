import 'package:flutter/foundation.dart';

enum StreamZoomPreset { hour, day }

class StreamTimeViewport extends ChangeNotifier {
  StreamTimeViewport({
    required this.baseEpochMs,
    StreamZoomPreset initialPreset = StreamZoomPreset.day,
  }) : _preset = initialPreset,
       _minutesPerPixel = minutesPerPixelFor(initialPreset);

  final int baseEpochMs;

  static const double hourMinutesPerPixel = 60.0 / 160.0;
  static const double dayMinutesPerPixel = 60.0 / 56.0;

  static double minutesPerPixelFor(StreamZoomPreset preset) {
    switch (preset) {
      case StreamZoomPreset.hour:
        return hourMinutesPerPixel;
      case StreamZoomPreset.day:
        return dayMinutesPerPixel;
    }
  }

  double _offsetPx = 0;
  double _minutesPerPixel = dayMinutesPerPixel;
  StreamZoomPreset _preset = StreamZoomPreset.day;
  double _viewportHeight = 0;
  final ValueNotifier<double> _offsetPxListenable = ValueNotifier<double>(0);

  double get offsetPx => _offsetPx;
  ValueListenable<double> get offsetPxListenable => _offsetPxListenable;
  double get minutesPerPixel => _minutesPerPixel;
  StreamZoomPreset get zoomPreset => _preset;
  double get viewportHeight => _viewportHeight;
  double get maxOffsetPx => _maxOffset();

  static const double _minMinutesPerPixel = hourMinutesPerPixel;
  static const double _maxMinutesPerPixel = dayMinutesPerPixel;

  void notify() => notifyListeners();

  @override
  void dispose() {
    _offsetPxListenable.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  bool setViewportHeight(double h, {bool notify = true}) {
    if (h == _viewportHeight) return false;
    _viewportHeight = h;
    _offsetPx = _offsetPx.clamp(0.0, _maxOffset());
    _offsetPxListenable.value = _offsetPx;
    if (notify) notifyListeners();
    return true;
  }

  void setOffset(double v, {bool notify = true}) {
    _offsetPx = v.clamp(0.0, _maxOffset());
    _offsetPxListenable.value = _offsetPx;
    if (notify) notifyListeners();
  }

  void setZoom(double minutesPerPixel, {double? focalPx, bool notify = true}) {
    final clamped = minutesPerPixel.clamp(
      _minMinutesPerPixel,
      _maxMinutesPerPixel,
    );
    if (focalPx != null) {
      final focalTimeMs =
          baseEpochMs + (_offsetPx + focalPx) * _minutesPerPixel * 60000.0;
      _minutesPerPixel = clamped;
      _offsetPx = (focalTimeMs - baseEpochMs) / (clamped * 60000.0) - focalPx;
    } else {
      _minutesPerPixel = clamped;
    }
    _offsetPx = _offsetPx.clamp(0.0, _maxOffset());
    _offsetPxListenable.value = _offsetPx;
    _preset = _nearestPreset(_minutesPerPixel);
    if (notify) notifyListeners();
  }

  void setZoomPreset(
    StreamZoomPreset preset, {
    double? focalPx,
    bool notify = true,
  }) {
    setZoom(minutesPerPixelFor(preset), focalPx: focalPx, notify: notify);
  }

  void panBy(double deltaPx) {
    setOffset(_offsetPx - deltaPx);
  }

  double _maxOffset() {
    const totalMs = 365 * 24 * 60 * 60 * 1000;
    final totalPx = totalMs / (_minutesPerPixel * 60000.0);
    final max = totalPx - _viewportHeight;
    return max < 0 ? 0 : max;
  }

  StreamZoomPreset _nearestPreset(double mpp) {
    double bestDist = double.infinity;
    StreamZoomPreset best = StreamZoomPreset.day;
    for (final p in StreamZoomPreset.values) {
      final d = (minutesPerPixelFor(p) - mpp).abs();
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    return best;
  }

  double timeToPx(int epochMs) =>
      (epochMs - baseEpochMs) / (_minutesPerPixel * 60000.0) - _offsetPx;

  int pxToTime(double px) =>
      baseEpochMs + ((px + _offsetPx) * _minutesPerPixel * 60000.0).round();
}
