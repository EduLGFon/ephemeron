import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ephemeron/l10n/src/app_localizations.dart';

import '../../../core/ui/app_feedback.dart';
import '../../../domain/habits/date_key.dart';
import '../../habits/application/habits_providers.dart'
    show habitRepositoryProvider;
import '../application/stream_day_mark.dart';
import '../application/stream_day_providers.dart';
import '../engine/stream_time_viewport.dart';
import 'stream_day_body_view.dart';
import 'stream_day_controller.dart';
import 'stream_time_format.dart';
import 'surface/stream_peek_sheet.dart';

class StreamDayBody extends ConsumerStatefulWidget {
  const StreamDayBody({
    super.key,
    required this.date,
    this.now,
    this.clock,
    this.onDateChanged,
    this.onReturnToNow,
    this.controller,
  });

  final DateTime date;
  final DateTime? now;
  final DateTime Function()? clock;
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback? onReturnToNow;
  final StreamDayBodyController? controller;

  @override
  ConsumerState<StreamDayBody> createState() => _StreamDayBodyState();
}

class _StreamDayBodyState extends ConsumerState<StreamDayBody> {
  late StreamTimeViewport _viewport;
  late StreamDayBodyController _controller;
  bool _ownsController = false;
  late final ValueNotifier<String> _timeLabel;
  late final ValueNotifier<bool> _away;
  Timer? _timer;
  int _centerRetries = 0;
  static const int _maxCenterRetries = 5;

  DateTime get _now => widget.clock?.call() ?? widget.now ?? DateTime.now();

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
    _controller = _bindController();
    _attachController();
    _timeLabel = ValueNotifier<String>('');
    _away = ValueNotifier<bool>(false);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _timeLabel.value = formatStreamTimeOfDay(context, _now);
    });
    _viewport.addListener(_updateAway);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timeLabel.value = formatStreamTimeOfDay(context, _now);
      _centerViewport();
      _updateAway();
    });
  }

  @override
  void didUpdateWidget(covariant StreamDayBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    final dateChanged = oldWidget.date != widget.date;
    if (controllerChanged) {
      _controller.detach(_viewport);
      if (_ownsController) _controller.dispose();
      _controller = _bindController();
    }
    if (dateChanged) {
      _centerRetries = 0;
      _viewport.removeListener(_updateAway);
      _viewport.dispose();
      _viewport = StreamTimeViewport(
        baseEpochMs: _dayStart.millisecondsSinceEpoch,
      );
      _viewport.addListener(_updateAway);
      _attachController();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _centerViewport();
        _updateAway();
      });
    } else if (controllerChanged) {
      _attachController();
    }
  }

  @override
  void dispose() {
    _controller.detach(_viewport);
    if (_ownsController) _controller.dispose();
    _timer?.cancel();
    _viewport.removeListener(_updateAway);
    _viewport.dispose();
    _timeLabel.dispose();
    _away.dispose();
    super.dispose();
  }

  /// Uses the caller's controller when supplied, otherwise owns one so the
  /// ambient layers always have a live viewport binding.
  StreamDayBodyController _bindController() {
    final provided = widget.controller;
    if (provided != null) {
      _ownsController = false;
      return provided;
    }
    _ownsController = true;
    return StreamDayBodyController();
  }

  void _attachController() {
    _controller.attach(
      viewport: _viewport,
      date: widget.date,
      clock: () => _now,
    );
  }

  void _centerViewport() {
    final height = _viewport.viewportHeight;
    if (!_isToday) {
      _viewport.setOffset(8 * 60 / _viewport.minutesPerPixel);
      _away.value = false;
      _centerRetries = 0;
      return;
    }
    if (height <= 0) {
      if (_centerRetries < _maxCenterRetries) {
        _centerRetries++;
        WidgetsBinding.instance.addPostFrameCallback((_) => _centerViewport());
      }
      return;
    }
    _centerRetries = 0;
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

  /// Opens Peek for the tapped mark. The sheet owns loading and saving; a tap
  /// whose id is no longer in the loaded marks is ignored.
  void _openMark(List<StreamDayMark> marks, String id) {
    for (final mark in marks) {
      if (mark.id != id) continue;
      unawaited(showStreamPeek(context, mark: mark));
      return;
    }
  }

  void _toggleHabit(String id) {
    AppFeedback.selection();
    unawaited(_writeHabitToggle(id));
  }

  /// The gutter reflects the log stream, so a failed write leaves the glyph
  /// unchanged and is only reported to the debug console.
  Future<void> _writeHabitToggle(String id) async {
    try {
      await ref
          .read(habitRepositoryProvider)
          .toggleHabitDone(id, habitDateKey(widget.date));
    } catch (error) {
      debugPrint('Stream habit toggle failed: $error');
    }
  }

  /// Countdown taps and "show all" both open the Countdowns tab. The Stream
  /// has no countdown editor of its own; reusing /tab4 keeps a single editor.
  void _openCountdowns() {
    GoRouter.maybeOf(context)?.go('/tab4');
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
      controller: _controller,
      marks: marks,
      isToday: _isToday,
      now: _now,
      timeLabel: _timeLabel,
      away: _away,
      onDateChanged: widget.onDateChanged,
      onReturnToNow: _returnToNow,
      l: l,
      date: widget.date,
      currentDayKey: habitDateKey(widget.date),
      onMarkTap: (id) => _openMark(marks, id),
      onHabitToggle: _toggleHabit,
      onCountdownTap: (_) => _openCountdowns(),
      onShowAllCountdowns: _openCountdowns,
    );
  }
}
