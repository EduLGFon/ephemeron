part of 'week_view.dart';

class _WeekViewState extends State<WeekView> {
  late List<List<StreamDayMark>> _buckets;
  double _textScale = 1.0;
  int? _lastCulled;

  @override
  void initState() {
    super.initState();
    _prepare();
    _scheduleCulled();
  }

  @override
  void didUpdateWidget(covariant WeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.marks, widget.marks) ||
        !identical(oldWidget.dayMarks, widget.dayMarks) ||
        oldWidget.weekStart != widget.weekStart ||
        oldWidget.visibleStart != widget.visibleStart ||
        oldWidget.visibleEnd != widget.visibleEnd) {
      _prepare();
    }
    _scheduleCulled();
  }

  void _prepare() {
    final ws = DateTime(
      widget.weekStart.year,
      widget.weekStart.month,
      widget.weekStart.day,
    );
    final buckets = List<List<StreamDayMark>>.generate(
      7,
      (_) => <StreamDayMark>[],
    );
    if (widget.dayMarks != null) {
      for (var i = 0; i < 7 && i < widget.dayMarks!.length; i++) {
        buckets[i] = List<StreamDayMark>.from(widget.dayMarks![i])..sort(_cmp);
      }
    } else if (widget.marks != null) {
      for (final m in widget.marks!) {
        final d = LevelData.localDay(m.startMs);
        final idx = d.difference(ws).inDays;
        if (idx >= 0 && idx < 7) buckets[idx].add(m);
      }
      for (final b in buckets) {
        b.sort(_cmp);
      }
    }
    _buckets = buckets;
  }

  static int _cmp(StreamDayMark a, StreamDayMark b) {
    final c = a.startMs.compareTo(b.startMs);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  bool _dayVisible(int dayIndex) {
    final date = widget.weekStart.add(Duration(days: dayIndex));
    if (widget.visibleStart != null && date.isBefore(widget.visibleStart!)) {
      return false;
    }
    if (widget.visibleEnd != null && date.isAfter(widget.visibleEnd!)) {
      return false;
    }
    if (widget.visibleRangeStartMs != null &&
        date.millisecondsSinceEpoch < widget.visibleRangeStartMs!) {
      return false;
    }
    if (widget.visibleRangeEndMs != null &&
        date.millisecondsSinceEpoch > widget.visibleRangeEndMs!) {
      return false;
    }
    return true;
  }

  int _culledCount() {
    final total =
        widget.marks?.length ??
        (widget.dayMarks?.fold<int>(0, (a, b) => a + b.length) ?? 0);
    var visible = 0;
    for (var day = 0; day < 7; day++) {
      if (!_dayVisible(day)) continue;
      visible += _buckets[day].length;
    }
    return total - visible;
  }

  void _scheduleCulled() {
    final value = _culledCount();
    if (value == _lastCulled) return;
    _lastCulled = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCulledCount?.call(value);
    });
  }

  Rect _chipRect(int dayIndex, int chipIndex) {
    final headerH = 20.0 * _textScale;
    final chipH = 14.0 * _textScale;
    final gap = 2.0 * _textScale;
    final x = dayIndex * widget.cellWidth;
    final y = headerH + 4 * _textScale + chipIndex * (chipH + gap);
    return Rect.fromLTWH(x + 2, y, widget.cellWidth - 4, chipH);
  }

  int _hitDay(double x) {
    final idx = (x / widget.cellWidth).floor();
    return idx.clamp(0, 6);
  }

  Widget _markSemanticsOverlay(int dayIndex, int chipIndex) {
    final bucket = _buckets[dayIndex];
    final m = bucket[chipIndex];
    final r = _chipRect(dayIndex, chipIndex);
    final label = widget.markSemanticsLabel(m);
    final actions = <CustomSemanticsAction, VoidCallback>{};
    final labels = widget.markActionLabels;
    String actionLabel(String key) => labels[key]!;
    if (widget.onCompleteMark != null) {
      actions[CustomSemanticsAction(label: actionLabel('complete'))] = () =>
          widget.onCompleteMark!(m.id);
    }
    if (widget.onPushMark != null) {
      actions[CustomSemanticsAction(label: actionLabel('push'))] = () =>
          widget.onPushMark!(m.id);
    }
    if (widget.onRescheduleMark != null) {
      actions[CustomSemanticsAction(label: actionLabel('reschedule'))] = () =>
          widget.onRescheduleMark!(m.id);
    }
    if (widget.onDeleteMark != null) {
      actions[CustomSemanticsAction(label: actionLabel('delete'))] = () =>
          widget.onDeleteMark!(m.id);
    }
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: IgnorePointer(
        child: Semantics(
          label: label,
          textDirection: TextDirection.ltr,
          onTap: widget.onMarkTap != null
              ? () => widget.onMarkTap!(m.id)
              : null,
          customSemanticsActions: actions.isEmpty ? null : actions,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final dayIndex = _hitDay(details.localPosition.dx);
        final date = widget.weekStart.add(Duration(days: dayIndex));
        if (!_dayVisible(dayIndex)) {
          widget.onDayTap?.call(date);
          return;
        }
        String? markId;
        for (var ci = 0; ci < widget.maxChips; ci++) {
          final bucket = _buckets[dayIndex];
          if (ci >= bucket.length) break;
          final r = _chipRect(dayIndex, ci);
          if (r.contains(details.localPosition)) {
            markId = bucket[ci].id;
            break;
          }
        }
        if (markId != null) {
          widget.onMarkTap?.call(markId);
        } else {
          widget.onDayTap?.call(date);
        }
      },
      child: Stack(
        children: [
          CustomPaint(
            painter: _WeekPainter(
              weekStart: widget.weekStart,
              buckets: _buckets,
              cellWidth: widget.cellWidth,
              height: widget.resolvedHeight,
              textScale: _textScale,
              dayHeaderBuilder: widget.dayHeaderBuilder,
              daySemanticsLabel: widget.daySemanticsLabel,
              habitRows: widget.habitRows ?? const <WeekHabitDotRow>[],
              maxChips: widget.maxChips,
              overflowLabelBuilder: widget.overflowLabelBuilder,
              dayVisible: _dayVisible,
              markSemanticsLabel: widget.markSemanticsLabel,
              onDayTap: widget.onDayTap,
              onCompleteMark: widget.onCompleteMark,
              onPushMark: widget.onPushMark,
              onRescheduleMark: widget.onRescheduleMark,
              onDeleteMark: widget.onDeleteMark,
              markActionLabels: widget.markActionLabels,
            ),
            size: Size(widget.cellWidth * 7, widget.resolvedHeight),
          ),
          for (var day = 0; day < 7; day++)
            if (_dayVisible(day))
              for (
                var ci = 0;
                ci < math.min(widget.maxChips, _buckets[day].length);
                ci++
              )
                _markSemanticsOverlay(day, ci),
        ],
      ),
    );
  }
}
