import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../application/stream_day_mark.dart';
import '../application/stream_day_providers.dart';
import '../design/stream_tokens.dart';
import '../engine/stream_time_viewport.dart';
import 'chrome/now_line.dart';
import 'chrome/scrubber.dart';
import 'chrome/time_rail.dart';
import 'day/day_canvas.dart';
import 'day/day_gestures.dart';
import 'now_pill.dart';

class StreamDayBody extends ConsumerStatefulWidget {
  const StreamDayBody({
    super.key,
    required this.date,
    this.onDateChanged,
    this.onReturnToNow,
  });

  final DateTime date;
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback? onReturnToNow;

  @override
  ConsumerState<StreamDayBody> createState() => _StreamDayBodyState();
}

class _StreamDayBodyState extends ConsumerState<StreamDayBody> {
  late final StreamTimeViewport _viewport;
  late final ValueNotifier<String> _timeLabel;
  late final ValueNotifier<bool> _away;
  Timer? _timer;

  DateTime get _dayStart =>
      DateTime(widget.date.year, widget.date.month, widget.date.day);

  @override
  void initState() {
    super.initState();
    _viewport = StreamTimeViewport(
      baseEpochMs: _dayStart.millisecondsSinceEpoch,
    );
    _timeLabel = ValueNotifier<String>(_formatTime(DateTime.now()));
    _away = ValueNotifier<bool>(false);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _timeLabel.value = _formatTime(DateTime.now());
    });
    _viewport.addListener(_updateAway);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateAway());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _viewport.removeListener(_updateAway);
    _viewport.dispose();
    _timeLabel.dispose();
    _away.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _updateAway() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final height = _viewport.viewportHeight;
    if (height <= 0) return;
    final nowPx = _viewport.timeToPx(nowMs);
    final target = height * 0.35;
    _away.value = (nowPx - target).abs() > height * 0.25;
  }

  void _returnToNow() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final height = _viewport.viewportHeight;
    final offset =
        (nowMs - _viewport.baseEpochMs) /
            (_viewport.minutesPerPixel * 60000.0) -
        height * 0.35;
    _viewport.setOffset(offset);
    _away.value = false;
    widget.onReturnToNow?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final key = StreamDayKey(
      year: widget.date.year,
      month: widget.date.month,
      day: widget.date.day,
    );
    final asyncMarks = ref.watch(streamMarksForDayProvider(key));
    final marks = asyncMarks.when(
      data: (d) => d.marks,
      loading: () => const <StreamDayMark>[],
      error: (_, _) => const <StreamDayMark>[],
    );
    final scrubberWidth = 48.0 + StreamSpacing.x6;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        DayGestureRegion(
          viewport: _viewport,
          onGestureEnd: () {
            final centerMs = _viewport.pxToTime(_viewport.viewportHeight / 2);
            final centerDate = DateTime.fromMillisecondsSinceEpoch(centerMs);
            final day = DateTime(
              centerDate.year,
              centerDate.month,
              centerDate.day,
            );
            widget.onDateChanged?.call(day);
          },
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: ListenableBuilder(
                  listenable: _viewport,
                  builder: (context, _) => TimeRail(
                    hourCount: 24 * 365,
                    hourHeight: 60.0 / _viewport.minutesPerPixel,
                    hourLabelBuilder: (i) =>
                        '${(i % 24).toString().padLeft(2, '0')}:00',
                    scrollOffsetListenable: null,
                  ),
                ),
              ),
              Expanded(
                child: DayCanvas(
                  viewport: _viewport,
                  marks: marks,
                  timeFormatter: (ms) {
                    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
                    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  },
                ),
              ),
              SizedBox(
                width: scrubberWidth,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: StreamSpacing.x6,
                  ),
                  child: ListenableBuilder(
                    listenable: _viewport,
                    builder: (context, _) {
                      final max = _viewport.maxOffsetPx;
                      final value = max <= 0
                          ? 0.0
                          : (_viewport.offsetPx / max).clamp(0.0, 1.0);
                      return Scrubber(
                        value: value,
                        semanticLabel: l.streamScrubber,
                        valueFormatter: (v) => '${(v * 100).round()}%',
                        onChanged: (v) {
                          _viewport.setOffset(v * _viewport.maxOffsetPx);
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
        ListenableBuilder(
          listenable: _viewport,
          builder: (context, _) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final y = _viewport.timeToPx(nowMs);
            return Positioned(
              top: y - 10,
              left: 56,
              right: scrubberWidth,
              child: NowLine(label: _timeLabel, liveRegion: true),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _away,
          builder: (context, away, _) {
            if (!away) return const SizedBox.shrink();
            return Positioned(
              bottom: 96,
              left: 0,
              right: 0,
              child: Center(
                child: NowPill(
                  label: l.streamNow,
                  visible: true,
                  onReturnToNow: _returnToNow,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
