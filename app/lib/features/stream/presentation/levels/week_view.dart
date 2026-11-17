import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/stream_day_mark.dart';
import 'level_data.dart';

class WeekHabitDotRow {
  const WeekHabitDotRow({required this.id, required this.done});

  final String id;
  final List<bool> done;
}

class WeekView extends StatefulWidget {
  const WeekView({
    super.key,
    required this.weekStart,
    this.dayMarks,
    this.marks,
    required this.cellWidth,
    required this.cellHeight,
    this.visibleStart,
    this.visibleEnd,
    this.visibleRangeStartMs,
    this.visibleRangeEndMs,
    required this.dayHeaderBuilder,
    required this.daySemanticsLabel,
    this.habitRows,
    this.maxChips = 3,
    this.overflowLabelBuilder,
    this.onDayTap,
    this.onMarkTap,
    this.onCulledCount,
    required this.markSemanticsLabel,
    this.onCompleteMark,
    this.onPushMark,
    this.onRescheduleMark,
    this.onDeleteMark,
    required this.markActionLabels,
  });

  final DateTime weekStart;
  final List<List<StreamDayMark>>? dayMarks;
  final List<StreamDayMark>? marks;
  final double cellWidth;
  final double cellHeight;
  final DateTime? visibleStart;
  final DateTime? visibleEnd;
  final int? visibleRangeStartMs;
  final int? visibleRangeEndMs;
  final String Function(int dayIndex, DateTime date) dayHeaderBuilder;
  final String Function(int dayIndex, [DateTime? date]) daySemanticsLabel;
  final List<WeekHabitDotRow>? habitRows;
  final int maxChips;
  final String Function(int remaining)? overflowLabelBuilder;
  final void Function(DateTime date)? onDayTap;
  final void Function(String markId)? onMarkTap;
  final void Function(int culledCount)? onCulledCount;
  final String Function(StreamDayMark mark) markSemanticsLabel;
  final void Function(String markId)? onCompleteMark;
  final void Function(String markId)? onPushMark;
  final void Function(String markId)? onRescheduleMark;
  final void Function(String markId)? onDeleteMark;
  final Map<String, String> markActionLabels;

  double get resolvedHeight => cellHeight;

  @override
  State<WeekView> createState() => _WeekViewState();
}

typedef StreamWeekView = WeekView;
typedef WeekLevelView = WeekView;

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
    String actionLabel(String key, String fallback) => labels[key] ?? fallback;
    if (widget.onCompleteMark != null) {
      actions[CustomSemanticsAction(
        label: actionLabel('complete', 'complete'),
      )] = () =>
          widget.onCompleteMark!(m.id);
    }
    if (widget.onPushMark != null) {
      actions[CustomSemanticsAction(label: actionLabel('push', 'push'))] = () =>
          widget.onPushMark!(m.id);
    }
    if (widget.onRescheduleMark != null) {
      actions[CustomSemanticsAction(
        label: actionLabel('reschedule', 'reschedule'),
      )] = () =>
          widget.onRescheduleMark!(m.id);
    }
    if (widget.onDeleteMark != null) {
      actions[CustomSemanticsAction(
        label: actionLabel('delete', 'delete'),
      )] = () =>
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

class _WeekPainter extends CustomPainter {
  _WeekPainter({
    required this.weekStart,
    required this.buckets,
    required this.cellWidth,
    required this.height,
    required this.textScale,
    required this.dayHeaderBuilder,
    required this.daySemanticsLabel,
    required this.habitRows,
    required this.maxChips,
    this.overflowLabelBuilder,
    required this.dayVisible,
    required this.markSemanticsLabel,
    this.onDayTap,
    this.onCompleteMark,
    this.onPushMark,
    this.onRescheduleMark,
    this.onDeleteMark,
    required this.markActionLabels,
  });

  final DateTime weekStart;
  final List<List<StreamDayMark>> buckets;
  final double cellWidth;
  final double height;
  final double textScale;
  final String Function(int, DateTime) dayHeaderBuilder;
  final String Function(int, [DateTime?]) daySemanticsLabel;
  final List<WeekHabitDotRow> habitRows;
  final int maxChips;
  final String Function(int)? overflowLabelBuilder;
  final bool Function(int) dayVisible;
  final String Function(StreamDayMark) markSemanticsLabel;
  final void Function(DateTime)? onDayTap;
  final void Function(String)? onCompleteMark;
  final void Function(String)? onPushMark;
  final void Function(String)? onRescheduleMark;
  final void Function(String)? onDeleteMark;
  final Map<String, String> markActionLabels;

  double get _headerH => 20.0 * textScale;
  double get _chipH => 14.0 * textScale;
  double get _gap => 2.0 * textScale;

  String _header(int i) =>
      dayHeaderBuilder(i, weekStart.add(Duration(days: i)));

  String _daySemantics(int i) =>
      daySemanticsLabel(i, weekStart.add(Duration(days: i)));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var day = 0; day < 7; day++) {
      if (!dayVisible(day)) continue;
      final x = day * cellWidth;
      final tp = TextPainter(
        text: TextSpan(
          text: _header(day),
          style: TextStyle(
            fontSize: 11 * textScale,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '\u2026',
      );
      tp.layout(maxWidth: cellWidth - 4);
      tp.paint(canvas, Offset(x + 2, 2));
      final bucket = buckets[day];
      final shown = math.min(maxChips, bucket.length);
      for (var ci = 0; ci < shown; ci++) {
        final m = bucket[ci];
        final rect = Rect.fromLTWH(
          x + 2,
          _headerH + 4 * textScale + ci * (_chipH + _gap),
          cellWidth - 4,
          _chipH,
        );
        paint.color = Color(m.colorArgb);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          paint,
        );
      }
      if (bucket.length > maxChips) {
        final remaining = bucket.length - maxChips;
        final label = overflowLabelBuilder != null
            ? overflowLabelBuilder!(remaining)
            : '+$remaining';
        final oTp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(fontSize: 10 * textScale),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        oTp.layout(maxWidth: cellWidth - 4);
        oTp.paint(
          canvas,
          Offset(x + 2, _headerH + 4 * textScale + shown * (_chipH + _gap)),
        );
      }
    }
    var hy = height - ((habitRows.length) * 12.0 * textScale);
    if (hy < _headerH + 4 * textScale) hy = _headerH + 4 * textScale;
    for (final row in habitRows) {
      for (var day = 0; day < 7; day++) {
        if (!dayVisible(day)) continue;
        final done = day < row.done.length && row.done[day];
        final cx = day * cellWidth + cellWidth / 2;
        final cy = hy + 5 * textScale;
        paint.color = done ? const Color(0xFF4CAF50) : const Color(0xFFBDBDBD);
        canvas.drawCircle(Offset(cx, cy), 3 * textScale, paint);
      }
      hy += 12.0 * textScale;
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    final result = <CustomPainterSemantics>[];
    for (var day = 0; day < 7; day++) {
      if (!dayVisible(day)) continue;
      final x = day * cellWidth;
      final date = weekStart.add(Duration(days: day));
      result.add(
        CustomPainterSemantics(
          rect: Rect.fromLTWH(x, 0, cellWidth, height),
          properties: SemanticsProperties(
            label: _daySemantics(day),
            textDirection: TextDirection.ltr,
            onTap: onDayTap != null ? () => onDayTap!(date) : null,
          ),
        ),
      );
    }
    return result;
  };

  @override
  bool shouldRepaint(covariant _WeekPainter oldDelegate) => true;
}
