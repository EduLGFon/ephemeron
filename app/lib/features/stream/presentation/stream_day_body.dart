import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../application/stream_day_mark.dart';
import '../application/stream_day_providers.dart';
import '../engine/stream_time_viewport.dart';
import 'stream_day_body_view.dart';
import 'stream_time_format.dart';

class StreamDayBody extends ConsumerStatefulWidget {
  const StreamDayBody({
    super.key,
    required this.date,
    this.now,
    this.onDateChanged,
    this.onReturnToNow,
  });

  final DateTime date;
  final DateTime? now;
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback? onReturnToNow;

  @override
  ConsumerState<StreamDayBody> createState() => _StreamDayBodyState();
}

class _StreamDayBodyState extends ConsumerState<StreamDayBody> {
  late StreamTimeViewport _viewport;
  late final ValueNotifier<String> _timeLabel;
  late final ValueNotifier<bool> _away;
  Timer? _timer;

  DateTime get _now => widget.now ?? DateTime.now();

  DateTime get _dayStart =>
      DateTime(widget.date.year, widget.date.month, widget.date.day);

  bool get _isToday {
    final now = _now;
    return widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _viewport = StreamTimeViewport(
      baseEpochMs: _dayStart.millisecondsSinceEpoch,
    );
    _timeLabel = ValueNotifier<String>('');
    _away = ValueNotifier<bool>(false);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _timeLabel.value = formatStreamTimeOfDay(context, DateTime.now());
    });
    _viewport.addListener(_updateAway);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timeLabel.value = formatStreamTimeOfDay(context, DateTime.now());
      _centerViewport();
      _updateAway();
    });
  }

  @override
  void didUpdateWidget(covariant StreamDayBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _viewport.removeListener(_updateAway);
      _viewport.dispose();
      _viewport = StreamTimeViewport(
        baseEpochMs: _dayStart.millisecondsSinceEpoch,
      );
      _viewport.addListener(_updateAway);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _centerViewport();
        _updateAway();
      });
    }
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

  void _centerViewport() {
    final height = _viewport.viewportHeight;
    if (!_isToday) {
      _viewport.setOffset(8 * 60 / _viewport.minutesPerPixel);
      _away.value = false;
      return;
    }
    if (height <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerViewport());
      return;
    }
    final nowMs = _now.millisecondsSinceEpoch;
    final offset =
        (nowMs - _viewport.baseEpochMs) /
            (_viewport.minutesPerPixel * 60000.0) -
        height * 0.35;
    _viewport.setOffset(offset);
    _away.value = false;
  }

  void _updateAway() {
    if (!_isToday) {
      _away.value = false;
      return;
    }
    final nowMs = _now.millisecondsSinceEpoch;
    final height = _viewport.viewportHeight;
    if (height <= 0) return;
    final nowPx = _viewport.timeToPx(nowMs);
    final target = height * 0.35;
    _away.value = (nowPx - target).abs() > height * 0.25;
  }

  void _returnToNow() {
    _centerViewport();
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

    return StreamDayBodyView(
      viewport: _viewport,
      marks: marks,
      isToday: _isToday,
      now: _now,
      timeLabel: _timeLabel,
      away: _away,
      onDateChanged: widget.onDateChanged,
      onReturnToNow: _returnToNow,
      l: l,
      date: widget.date,
    );
  }
}
