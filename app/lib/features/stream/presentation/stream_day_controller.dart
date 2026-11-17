import 'package:flutter/foundation.dart';

import '../engine/stream_time_viewport.dart';

/// Seam between the stream day body and ambient stream overlays.
///
/// Overlays read the live [viewport] and map wall-clock times to vertical
/// positions without reaching into the body's private state. The body owns the
/// viewport lifecycle; this controller only holds a reference while attached
/// and never disposes it.
class StreamDayBodyController extends ChangeNotifier {
  StreamTimeViewport? _viewport;
  DateTime? _date;
  DateTime Function()? _clock;

  bool get attached => _viewport != null;

  StreamTimeViewport? get viewport => _viewport;

  DateTime? get date => _date;

  DateTime Function()? get clock => _clock;

  DateTime? get now => _clock?.call();

  /// Offset listenable of the attached viewport, or null when detached.
  Listenable? get scrollListenable => _viewport?.offsetPxListenable;

  /// Vertical position of [time] in the viewport, or null when detached.
  double? timeToY(DateTime time) {
    final viewport = _viewport;
    if (viewport == null) return null;
    return viewport.timeToPx(time.millisecondsSinceEpoch);
  }

  /// Wall-clock time at vertical position [y], or null when detached.
  DateTime? pxToTime(double y) {
    final viewport = _viewport;
    if (viewport == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(viewport.pxToTime(y));
  }

  /// Binds this controller to [viewport] for [date].
  ///
  /// Re-attaching the same viewport and date is a no-op apart from refreshing
  /// [clock]; listeners are notified only when the binding actually changes.
  void attach({
    required StreamTimeViewport viewport,
    required DateTime date,
    DateTime Function()? clock,
  }) {
    _clock = clock;
    if (identical(_viewport, viewport) && _date == date) return;
    _viewport = viewport;
    _date = date;
    notifyListeners();
  }

  /// Clears the binding when [viewport] is the attached one.
  ///
  /// Detaching a viewport this controller is not attached to is ignored.
  void detach(StreamTimeViewport viewport) {
    if (!identical(_viewport, viewport)) return;
    _clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  void _clear() {
    _viewport = null;
    _date = null;
    _clock = null;
  }
}
