import 'package:material_ui/material_ui.dart';

import '../application/stream_day_mark.dart';
import '../design/stream_tokens.dart';
import '../engine/mark_culler.dart';
import '../engine/mark_hit_test.dart';
import '../engine/stream_mark_layout.dart';
import '../engine/stream_time_viewport.dart';

import 'package:ephemeron/l10n/src/app_localizations.dart';

import 'chrome/now_line.dart';
import 'chrome/scrubber.dart';
import 'chrome/time_rail.dart';
import 'day/day_canvas.dart';
import 'day/day_gestures.dart';
import 'now_pill.dart';
import 'stream_time_format.dart';
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
    this.onMarkTap,
  });

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
  final ValueChanged<String>? onMarkTap;

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

  @override
  Widget build(BuildContext context) {
    final scrubberWidth = 48.0 + StreamSpacing.x6;
    final sortedMarks = _sortedMarks();
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        DayGestureRegion(
          viewport: viewport,
          onGestureEnd: () {
            final centerMs = viewport.pxToTime(viewport.viewportHeight / 2);
            final centerDate = DateTime.fromMillisecondsSinceEpoch(centerMs);
            final day = DateTime(
              centerDate.year,
              centerDate.month,
              centerDate.day,
            );
            onDateChanged?.call(day);
          },
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: ListenableBuilder(
                  listenable: viewport,
                  builder: (context, _) => TimeRail(
                    hourHeight: 60.0 / viewport.minutesPerPixel,
                    hourLabelBuilder: (i) => formatStreamTimeOfDay(
                      context,
                      date.add(Duration(hours: i)),
                    ),
                    scrollOffsetListenable: viewport.offsetPxListenable,
                  ),
                ),
              ),
              Expanded(
                child: _markCanvas(
                  sortedMarks,
                  DayCanvas(
                    viewport: viewport,
                    marks: marks,
                    timeFormatter: (ms) => formatStreamTimeOfDay(
                      context,
                      DateTime.fromMillisecondsSinceEpoch(ms),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: scrubberWidth,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: StreamSpacing.x6,
                  ),
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
                ),
              ),
            ],
          ),
        ),
        if (isToday)
          ListenableBuilder(
            listenable: viewport,
            builder: (context, _) {
              final nowY = viewport.timeToPx(now.millisecondsSinceEpoch);
              return Positioned.fill(
                child: Stack(
                  children: [
                    Positioned(
                      top: nowY - 10,
                      left: 56,
                      right: scrubberWidth,
                      child: NowLine(label: timeLabel, liveRegion: true),
                    ),
                    Positioned(
                      top: nowY + 28,
                      left: 56,
                      right: scrubberWidth,
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
          ),
        ValueListenableBuilder<bool>(
          valueListenable: away,
          builder: (context, isAway, _) {
            if (!isToday || !isAway) return const SizedBox.shrink();
            return Positioned(
              bottom: 96,
              left: 0,
              right: 0,
              child: Center(
                child: NowPill(
                  label: l.streamNow,
                  onReturnToNow: onReturnToNow,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
