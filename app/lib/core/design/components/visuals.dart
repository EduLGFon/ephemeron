// Shared custom-painted visuals: progress rings, habit heatmaps and the
// animated checkmark. Painters sit inside RepaintBoundary widgets and only
// repaint when their own values change.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.strokeWidth = 4,
    this.color,
    this.trackColor,
    this.child,
    this.semanticsLabel,
    this.repaint,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;
  final String? semanticsLabel;
  final Listenable? repaint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;
    final percent = (clamped * 100).round();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: '$percent%',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: clamped, end: clamped),
          duration: reduce ? Duration.zero : DsMotion.normal,
          curve: DsMotion.standard,
          child: child,
          builder: (context, animated, child) => RepaintBoundary(
            child: CustomPaint(
              painter: _RingPainter(
                value: animated,
                color: color ?? scheme.primary,
                trackColor: trackColor ?? scheme.surfaceContainerHighest,
                strokeWidth: strokeWidth,
                repaint: repaint,
              ),
              child: Center(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    super.repaint,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.max(
      0.0,
      (math.min(size.width, size.height) - strokeWidth) / 2,
    );
    if (radius == 0) return;
    final center = size.center(Offset.zero);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);
    if (value <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

class AppHeatmap extends StatelessWidget {
  const AppHeatmap({
    super.key,
    required this.values,
    this.weeks = 16,
    this.cellSize = 12,
    this.gap = 3,
    this.color,
    this.semanticsLabel,
    this.onTapDay,
  });

  /// Values are oldest week first, seven entries per week, Monday first.
  /// Intensity is relative to the largest displayed value; non-positive values
  /// draw an empty outline.
  final List<num> values;
  final int weeks;
  final double cellSize;
  final double gap;
  final Color? color;
  final String? semanticsLabel;
  final ValueChanged<int>? onTapDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeWeeks = math.max(1, weeks);
    final cell = math.max(1.0, cellSize);
    final spacing = math.max(0.0, gap);
    final columns = values.isEmpty
        ? safeWeeks
        : math.min(safeWeeks, (values.length / 7).ceil());
    final start = math.max(0, values.length - columns * 7);
    final visible = columns * 7;
    final width = columns * cell + (columns - 1) * spacing;
    final height = 7 * cell + 6 * spacing;
    var active = 0;
    for (var i = start; i < math.min(start + visible, values.length); i++) {
      if (values[i] > 0) active++;
    }
    void handleTap(TapUpDetails details) {
      final column = (details.localPosition.dx / (cell + spacing)).floor();
      final row = (details.localPosition.dy / (cell + spacing)).floor();
      if (column < 0 || column >= columns || row < 0 || row >= 7) return;
      if (details.localPosition.dx - column * (cell + spacing) > cell) return;
      if (details.localPosition.dy - row * (cell + spacing) > cell) return;
      onTapDay?.call(start + column * 7 + row);
    }

    return Semantics(
      container: true,
      label: semanticsLabel,
      value: '$active/$visible',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onTapDay == null ? null : handleTap,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(width, height),
              painter: _HeatmapPainter(
                values: values,
                start: start,
                columns: columns,
                cellSize: cell,
                gap: spacing,
                color: color ?? scheme.primary,
                outlineColor: scheme.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.values,
    required this.start,
    required this.columns,
    required this.cellSize,
    required this.gap,
    required this.color,
    required this.outlineColor,
  });

  final List<num> values;
  final int start;
  final int columns;
  final double cellSize;
  final double gap;
  final Color color;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.fold<double>(
      0,
      (max, value) => value > max ? value.toDouble() : max,
    );
    final radius = Radius.circular(math.min(cellSize / 2, DsRadius.r8 / 2));
    final fill = Paint()..style = PaintingStyle.fill;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outlineColor;
    for (var column = 0; column < columns; column++) {
      for (var row = 0; row < 7; row++) {
        final index = start + column * 7 + row;
        final value = index < values.length ? values[index] : 0;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            column * (cellSize + gap),
            row * (cellSize + gap),
            cellSize,
            cellSize,
          ),
          radius,
        );
        if (value <= 0 || maxValue <= 0) {
          canvas.drawRRect(rect, outline);
          continue;
        }
        final ratio = (value / maxValue).clamp(0.0, 1.0);
        fill.color = color.withValues(
          alpha: ratio >= 0.75
              ? 0.9
              : ratio >= 0.5
              ? 0.7
              : ratio >= 0.25
              ? 0.45
              : 0.25,
        );
        canvas.drawRRect(rect, fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) =>
      old.start != start ||
      old.columns != columns ||
      old.cellSize != cellSize ||
      old.gap != gap ||
      old.color != color ||
      old.outlineColor != outlineColor ||
      !listEquals(old.values, values);
}

class AppCheckmark extends StatefulWidget {
  const AppCheckmark({
    super.key,
    required this.checked,
    this.size = 24,
    this.color,
    this.duration = const Duration(milliseconds: 200),
    this.animate = true,
  });

  final bool checked;
  final double size;
  final Color? color;
  final Duration duration;
  final bool animate;

  @override
  State<AppCheckmark> createState() => _AppCheckmarkState();
}

class _AppCheckmarkState extends State<AppCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.checked ? 1 : 0,
  );

  @override
  void didUpdateWidget(AppCheckmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checked != widget.checked ||
        oldWidget.animate != widget.animate ||
        oldWidget.duration != widget.duration) {
      _apply();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animate ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _controller.value = widget.checked ? 1 : 0;
    }
  }

  void _apply() {
    final target = widget.checked ? 1.0 : 0.0;
    if (!widget.animate ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _controller.value = target;
      return;
    }
    _controller.animateTo(
      target,
      duration: widget.duration,
      curve: DsMotion.standard,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      container: true,
      checked: widget.checked,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _CheckPainter(progress: _controller, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final value = progress.value;
    if (value <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.8, size.height * 0.28);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * value),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, size.width * 0.11)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress || old.color != color;
}
