import 'package:material_ui/material_ui.dart';

import '../application/stream_day_mark.dart';
import '../design/stream_tokens.dart';
import '../engine/stream_time_viewport.dart';

import 'package:ephemeron/l10n/src/app_localizations.dart';

import 'chrome/now_line.dart';
import 'chrome/scrubber.dart';
import 'chrome/time_rail.dart';
import 'day/day_canvas.dart';
import 'day/day_gestures.dart';
import 'now_pill.dart';
import 'stream_time_format.dart';

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

  @override
  Widget build(BuildContext context) {
    final scrubberWidth = 48.0 + StreamSpacing.x6;
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
                child: DayCanvas(
                  viewport: viewport,
                  marks: marks,
                  timeFormatter: (ms) => formatStreamTimeOfDay(
                    context,
                    DateTime.fromMillisecondsSinceEpoch(ms),
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
              final nowMs = now.millisecondsSinceEpoch;
              final y = viewport.timeToPx(nowMs);
              return Positioned(
                top: y - 10,
                left: 56,
                right: scrubberWidth,
                child: NowLine(label: timeLabel, liveRegion: true),
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
