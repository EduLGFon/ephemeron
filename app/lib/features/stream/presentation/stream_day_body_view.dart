import 'package:material_ui/material_ui.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../../domain/habits/date_key.dart';
import '../application/stream_day_mark.dart';
import '../design/stream_tokens.dart';
import '../engine/mark_culler.dart';
import '../engine/mark_hit_test.dart';
import '../engine/stream_mark_layout.dart';
import '../engine/stream_time_viewport.dart';
import 'chrome/now_line.dart';
import 'chrome/scrubber.dart';
import 'chrome/time_rail.dart';
import 'countdowns/countdown_edge_chips.dart';
import 'countdowns/countdown_landmark_item.dart';
import 'day/day_canvas.dart';
import 'day/day_gestures.dart';
import 'gestures/tray_drop_target.dart';
import 'now_pill.dart';
import 'stream_day_controller.dart';
import 'stream_time_format.dart';
import 'surface/stream_countdown_layer.dart';
import 'surface/stream_habit_layer.dart';
import 'surface/stream_slipped_sheet.dart';
import 'surface/stream_slipped_trail_host.dart';

class StreamDayBodyView extends StatelessWidget {
  const StreamDayBodyView({
    super.key,
    required this.viewport,
    required this.marks,
    required this.isToday,
    required this.now,
    required this.timeLabel,
    required this.away,
    required this.onDateChanged,
    required this.onReturnToNow,
    required this.l,
    required this.date,
    this.controller,
    this.currentDayKey,
    this.onHabitToggle,
    this.onCountdownTap,
    this.onShowAllCountdowns,
    this.onMarkTap,
    this.onTrayDrop,
  });

  static const double _railWidth = 56;
  static const double _scrubberColumnWidth = 48.0 + StreamSpacing.x6;

  final StreamTimeViewport viewport;
  final List<StreamDayMark> marks;
  final bool isToday;
  final DateTime now;
  final ValueNotifier<String> timeLabel;
  final ValueNotifier<bool> away;
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback onReturnToNow;
  final AppLocalizations l;
  final DateTime date;

  /// Live viewport binding for the ambient overlays. When null the view stays
  /// the plain day surface (used by tests and embedders without a controller).
  final StreamDayBodyController? controller;

  /// Day key for done state; defaults to [date]'s local calendar day.
  final String? currentDayKey;

  final void Function(String habitId)? onHabitToggle;
  final ValueChanged<String>? onCountdownTap;
  final VoidCallback? onShowAllCountdowns;
  final ValueChanged<String>? onMarkTap;

  /// Receives a tray chip id and the drop time from the marks canvas.
  ///
  /// The target listens for drags only; it adds no pan or scale recognizer, so
  /// map panning and pinch zooming stay with [DayGestureRegion]. A chip drag
  /// begins with a long press outside this region, so the two never compete.
  final void Function(String id, int dropTimeMs)? onTrayDrop;

  /// Marks the painter will draw, in the painter's order.
  ///
  /// [DayCanvasPainter] sorts by start time and culls to the viewport before
  /// packing overlap columns. Reusing the same sort, cull range and
  /// [layoutMarkColumns] defaults keeps tap hit columns identical to painted
  /// columns without changing the painter.
  List<StreamDayMark> _sortedMarks() {
    return List<StreamDayMark>.of(marks)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
  }

  static List<MarkLayout> _markLayouts(List<StreamDayMark> marks) {
    return layoutMarkColumns([
      for (final m in marks)
        MarkInterval(startMs: m.startMs, endMs: m.endMs, id: m.id),
    ]);
  }

  Widget _markCanvas(List<StreamDayMark> sortedMarks, Widget canvas) {
    final starts = [for (final m in sortedMarks) m.startMs];
    final ends = [for (final m in sortedMarks) m.endMs];
    return ListenableBuilder(
      listenable: viewport,
      child: canvas,
      builder: (context, canvas) {
        final t0 = viewport.pxToTime(0);
        final t1 = viewport.pxToTime(viewport.viewportHeight);
        final range = cullMarks(starts, ends, t0, t1);
        final painted = sortedMarks.sublist(range.start, range.end);
        final layouts = _markLayouts(painted);
        final handler = onMarkTap;
        return LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: handler == null
                ? null
                : (details) => _handleTap(
                    details,
                    painted,
                    layouts,
                    constraints.maxWidth,
                  ),
            child: canvas!,
          ),
        );
      },
    );
  }

  /// Opens the mark under a tap.
  ///
  /// The tap recognizer shares the arena with the outer [DayGestureRegion]
  /// scale recognizer: a drag or pinch wins and the tap is rejected, so pan and
  /// zoom never open a mark, and a tap without movement never starts a pan.
  void _handleTap(
    TapUpDetails details,
    List<StreamDayMark> marks,
    List<MarkLayout> layouts,
    double canvasWidth,
  ) {
    final handler = onMarkTap;
    if (handler == null) return;
    final id = hitTestMark(
      marks: marks,
      layout: layouts,
      viewport: viewport,
      focalY: details.localPosition.dy,
      canvasWidth: canvasWidth,
      focalX: details.localPosition.dx,
      edgeMarginDp: 0,
    );
    if (id != null) handler(id);
  }

  void _onGestureEnd() {
    final centerMs = viewport.pxToTime(viewport.viewportHeight / 2);
    final centerDate = DateTime.fromMillisecondsSinceEpoch(centerMs);
    final day = DateTime(centerDate.year, centerDate.month, centerDate.day);
    onDateChanged?.call(day);
  }

  Widget _timeRail() {
    return ListenableBuilder(
      listenable: viewport,
      builder: (context, _) => TimeRail(
        hourHeight: 60.0 / viewport.minutesPerPixel,
        hourLabelBuilder: (i) =>
            formatStreamTimeOfDay(context, date.add(Duration(hours: i))),
        scrollOffsetListenable: viewport.offsetPxListenable,
      ),
    );
  }

  Widget _scrubber() {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: StreamSpacing.x6),
      child: ListenableBuilder(
        listenable: viewport,
        builder: (context, _) {
          final max = viewport.maxOffsetPx;
          final value = max <= 0
              ? 0.0
              : (viewport.offsetPx / max).clamp(0.0, 1.0);
          return Scrubber(
            value: value,
            semanticLabel: l.streamScrubber,
            valueFormatter: (v) => '${(v * 100).round()}%',
            onChanged: (v) {
              viewport.setOffset(v * viewport.maxOffsetPx);
            },
            onChangeEnd: (_) {},
          );
        },
      ),
    );
  }

  Widget _gestureColumn(BuildContext context, List<StreamDayMark> sortedMarks) {
    final canvas = _markCanvas(
      sortedMarks,
      DayCanvas(
        viewport: viewport,
        marks: marks,
        timeFormatter: (ms) => formatStreamTimeOfDay(
          context,
          DateTime.fromMillisecondsSinceEpoch(ms),
        ),
      ),
    );
    final trayDrop = onTrayDrop;
    return DayGestureRegion(
      viewport: viewport,
      onGestureEnd: _onGestureEnd,
      child: Row(
        children: [
          SizedBox(width: _railWidth, child: _timeRail()),
          Expanded(
            // Wraps only the marks area so the drop y maps to the same
            // viewport pixels the canvas paints; rail and scrubber stay
            // outside the target.
            child: trayDrop == null
                ? canvas
                : TrayDropTarget(
                    viewport: viewport,
                    onTrayDrop: trayDrop,
                    child: canvas,
                  ),
          ),
          SizedBox(width: _scrubberColumnWidth, child: _scrubber()),
        ],
      ),
    );
  }

  /// Habit gutter and countdown landmarks over the day surface.
  ///
  /// Mounted after the gesture region so their glyphs and landmarks receive
  /// taps; their widgets only hit-test their own children, so the canvas
  /// outside them keeps panning and zooming. The countdown layer maps by the
  /// viewport height that the day canvas sets during layout, so this overlay
  /// listens to the viewport to pick up that height (scroll rebuilds stay
  /// inside the overlay, never the canvas).
  List<Widget> _ambientLayers() {
    final controller = this.controller;
    if (controller == null) return const <Widget>[];
    final dayKey = currentDayKey ?? habitDateKey(date);
    return [
      StreamHabitLayer(
        controller: controller,
        day: date,
        currentDayKey: dayKey,
        onToggle: onHabitToggle ?? (_) {},
        streakLabel: _streakLabel,
      ),
      ListenableBuilder(
        listenable: viewport,
        builder: (context, _) => StreamCountdownLayer(
          controller: controller,
          day: date,
          now: now,
          labelBuilder: _countdownLabel,
          onTap: onCountdownTap ?? (_) {},
          onShowAll: onShowAllCountdowns ?? () {},
          // Top edge keeps chips clear of the NowPill and dock at the bottom.
          edge: CountdownEdge.top,
        ),
      ),
    ];
  }

  String _streakLabel(String _, int current, int best) =>
      l.streamHabitStreak(current, best);

  String _countdownLabel(CountdownLandmarkItem _, int days) =>
      days < 0 ? l.streamCountdownDaysAgo(-days) : l.streamCountdownDays(days);

  Widget _nowOverlay() {
    return ListenableBuilder(
      listenable: viewport,
      builder: (context, _) {
        final nowY = viewport.timeToPx(now.millisecondsSinceEpoch);
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned(
                top: nowY - 10,
                left: _railWidth,
                right: _scrubberColumnWidth,
                child: NowLine(label: timeLabel, liveRegion: true),
              ),
              Positioned(
                top: nowY + 28,
                left: _railWidth,
                right: _scrubberColumnWidth,
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  heightFactor: 1,
                  child: StreamSlippedTrailHost(
                    onOpenTriage: () => showStreamSlippedTriage(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _nowPill() {
    return ValueListenableBuilder<bool>(
      valueListenable: away,
      builder: (context, isAway, _) {
        if (!isToday || !isAway) return const SizedBox.shrink();
        return Positioned(
          bottom: 96,
          left: 0,
          right: 0,
          child: Center(
            child: NowPill(label: l.streamNow, onReturnToNow: onReturnToNow),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedMarks = _sortedMarks();
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        _gestureColumn(context, sortedMarks),
        ..._ambientLayers(),
        if (isToday) _nowOverlay(),
        _nowPill(),
      ],
    );
  }
}
