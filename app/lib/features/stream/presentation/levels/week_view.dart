import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/stream_day_mark.dart';
import 'level_data.dart';

/// Caller-supplied dot row for habits at week level: an id plus one done flag
/// per day of the week (7 entries).
class WeekHabitDotRow {
  const WeekHabitDotRow({required this.id, required this.done});

  final String id;
  final List<bool> done;
}

/// L3 week level: 7 compact day columns. Presentation only; data injected.
class WeekView extends StatefulWidget {
  const WeekView({
    super.key,
    required this.weekStart,
    this.dayMarks,
    this.marks,
    required this.cellWidth,
    this.height,
    this.cellHeight,
    this.visibleStart,
    this.visibleEnd,
    this.visibleRangeStartMs,
    this.visibleRangeEndMs,
    this.dayHeaders,
    this.dayHeaderBuilder,
    this.habitRows,
    this.maxChips = 3,
    this.overflowLabelBuilder,
    this.onDayTap,
    this.onMarkTap,
    this.onCulledCount,
    this.daySemanticsLabels,
    this.markSemanticsLabel,
    this.onCompleteMark,
    this.onPushMark,
    this.onRescheduleMark,
    this.onDeleteMark,
    this.markActionLabels,
  }) : assert(height != null || cellHeight != null);

  final DateTime weekStart;
  final List<List<StreamDayMark>>? dayMarks;
  final List<StreamDayMark>? marks;
  final double cellWidth;
  final double? height;
  final double? cellHeight;
  final DateTime? visibleStart;
  final DateTime? visibleEnd;
  final int? visibleRangeStartMs;
  final int? visibleRangeEndMs;
  final List<String>? dayHeaders;
  final String Function(int dayIndex, DateTime date)? dayHeaderBuilder;
  final List<WeekHabitDotRow>? habitRows;
  final int maxChips;
  final String Function(int remaining)? overflowLabelBuilder;
  final void Function(DateTime date)? onDayTap;
  final void Function(String markId)? onMarkTap;
  final void Function(int culledCount)? onCulledCount;
  final List<String>? daySemanticsLabels;
  final String Function(StreamDayMark mark)? markSemanticsLabel;
  final void Function(String markId)? onCompleteMark;
  final void Function(String markId)? onPushMark;
  final void Function(String markId)? onRescheduleMark;
  final void Function(String markId)? onDeleteMark;
  final Map<String, String>? markActionLabels;

  double get resolvedHeight => height ?? cellHeight!;

  @override
  State<WeekView> createState() => _WeekViewState();
}

typedef StreamWeekView = WeekView;
typedef WeekLevelView = WeekView;

class _WeekViewState extends State<WeekView> {
  late List<List<StreamDayMark>> _buckets;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant WeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.marks, widget.marks) ||
        !identical(oldWidget.dayMarks, widget.dayMarks) ||
        oldWidget.weekStart != widget.weekStart) {
      _prepare();
    }
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

  Rect _chipRect(int dayIndex, int chipIndex, double height) {
    const headerH = 20.0;
    const chipH = 14.0;
    const gap = 2.0;
    final x = dayIndex * widget.cellWidth;
    final y = headerH + 4 + chipIndex * (chipH + gap);
    return Rect.fromLTWH(x + 2, y, widget.cellWidth - 4, chipH);
  }

  int _hitDay(double x) {
    final idx = (x / widget.cellWidth).floor();
    return idx.clamp(0, 6);
  }

  Widget _markSemanticsOverlay(int dayIndex, int chipIndex) {
    final bucket = _buckets[dayIndex];
    final m = bucket[chipIndex];
    final r = _chipRect(dayIndex, chipIndex, widget.resolvedHeight);
    final label = widget.markSemanticsLabel != null
        ? widget.markSemanticsLabel!(m)
        : m.title;
    final actions = <CustomSemanticsAction, VoidCallback>{};
    final labels = widget.markActionLabels ?? const <String, String>{};
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
          customSemanticsActions: actions.isEmpty ? null : actions,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final dayIndex = _hitDay(details.localPosition.dx);
        final date = widget.weekStart.add(Duration(days: dayIndex));
        // check chips
        String? markId;
        for (var ci = 0; ci < widget.maxChips; ci++) {
          final idx = dayIndex;
          final bucket = _buckets[idx];
          if (ci >= bucket.length) break;
          final r = _chipRect(dayIndex, ci, widget.resolvedHeight);
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
              textScale: textScale,
              dayHeaders: widget.dayHeaders,
              dayHeaderBuilder: widget.dayHeaderBuilder,
              habitRows: widget.habitRows ?? const <WeekHabitDotRow>[],
              maxChips: widget.maxChips,
              overflowLabelBuilder: widget.overflowLabelBuilder,
              daySemanticsLabels: widget.daySemanticsLabels,
              markSemanticsLabel: widget.markSemanticsLabel,
              onCulledCount: widget.onCulledCount,
              onCompleteMark: widget.onCompleteMark,
              onPushMark: widget.onPushMark,
              onRescheduleMark: widget.onRescheduleMark,
              onDeleteMark: widget.onDeleteMark,
              markActionLabels: widget.markActionLabels,
            ),
            size: Size(widget.cellWidth * 7, widget.resolvedHeight),
          ),
          // Overlay Semantics nodes for visible marks. CustomPainterSemantics
          // does not transfer customSemanticsActions in this SDK, so an overlay
          // is required to expose complete/push/reschedule/delete actions.
          for (var day = 0; day < 7; day++)
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
    this.dayHeaders,
    this.dayHeaderBuilder,
    required this.habitRows,
    required this.maxChips,
    this.overflowLabelBuilder,
    this.daySemanticsLabels,
    this.markSemanticsLabel,
    this.onCulledCount,
    this.onCompleteMark,
    this.onPushMark,
    this.onRescheduleMark,
    this.onDeleteMark,
    this.markActionLabels,
  });

  final DateTime weekStart;
  final List<List<StreamDayMark>> buckets;
  final double cellWidth;
  final double height;
  final double textScale;
  final List<String>? dayHeaders;
  final String Function(int, DateTime)? dayHeaderBuilder;
  final List<WeekHabitDotRow> habitRows;
  final int maxChips;
  final String Function(int)? overflowLabelBuilder;
  final List<String>? daySemanticsLabels;
  final String Function(StreamDayMark)? markSemanticsLabel;
  final void Function(int)? onCulledCount;
  final void Function(String)? onCompleteMark;
  final void Function(String)? onPushMark;
  final void Function(String)? onRescheduleMark;
  final void Function(String)? onDeleteMark;
  final Map<String, String>? markActionLabels;

  static const double _headerH = 20.0;
  static const double _chipH = 14.0;
  static const double _gap = 2.0;

  String _header(int i) {
    if (dayHeaders != null && i < dayHeaders!.length) return dayHeaders![i];
    if (dayHeaderBuilder != null) {
      return dayHeaderBuilder!(i, weekStart.add(Duration(days: i)));
    }
    final d = weekStart.add(Duration(days: i));
    return '${d.weekday} ${d.day}';
  }

  String _daySemantics(int i) {
    if (daySemanticsLabels != null && i < daySemanticsLabels!.length) {
      return daySemanticsLabels![i];
    }
    return _header(i);
  }

  int _culledCount() {
    var n = 0;
    for (final b in buckets) {
      n += b.length;
    }
    return n;
  }

  @override
  void paint(Canvas canvas, Size size) {
    onCulledCount?.call(_culledCount());
    final paint = Paint()..style = PaintingStyle.fill;
    for (var day = 0; day < 7; day++) {
      final x = day * cellWidth;
      // header
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
      );
      tp.layout(maxWidth: cellWidth - 4);
      tp.paint(canvas, Offset(x + 2, 2));
      // chips
      final bucket = buckets[day];
      final shown = math.min(maxChips, bucket.length);
      for (var ci = 0; ci < shown; ci++) {
        final m = bucket[ci];
        final rect = Rect.fromLTWH(
          x + 2,
          _headerH + 4 + ci * (_chipH + _gap),
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
            style: TextStyle(
              fontSize: 10 * textScale,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        oTp.layout(maxWidth: cellWidth - 4);
        oTp.paint(
          canvas,
          Offset(x + 2, _headerH + 4 + shown * (_chipH + _gap)),
        );
      }
    }
    // habit dot rows
    var hy = height - (habitRows.length * 12.0);
    if (hy < _headerH + 4) hy = _headerH + 4;
    for (final row in habitRows) {
      for (var day = 0; day < 7; day++) {
        final done = day < row.done.length && row.done[day];
        final cx = day * cellWidth + cellWidth / 2;
        final cy = hy + 5;
        paint.color = done ? const Color(0xFF4CAF50) : const Color(0xFFBDBDBD);
        canvas.drawCircle(Offset(cx, cy), 3, paint);
      }
      hy += 12;
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    final result = <CustomPainterSemantics>[];
    for (var day = 0; day < 7; day++) {
      final x = day * cellWidth;
      result.add(
        CustomPainterSemantics(
          rect: Rect.fromLTWH(x, 0, cellWidth, height),
          properties: SemanticsProperties(
            label: _daySemantics(day),
            textDirection: TextDirection.ltr,
          ),
        ),
      );
      // Mark semantics are provided by an overlay of Semantics widgets
      // (see _WeekViewState.build): CustomPainterSemantics in this SDK does
      // not transfer customSemanticsActions, so custom actions would be lost.
    }
    return result;
  };

  @override
  bool shouldRepaint(covariant _WeekPainter oldDelegate) => true;
}
