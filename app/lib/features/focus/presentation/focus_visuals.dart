// Part of the focus screen library: the one-per-second countdown face.
part of 'focus_screen.dart';

/// Real clock/stopwatch face: tick marks around a goal-fill ring with tabular
/// digits in the center. Only this subtree listens to the one-second ticker.
class FocusTimeFace extends StatelessWidget {
  const FocusTimeFace({
    super.key,
    required this.now,
    required this.session,
    required this.strings,
    this.size = 232,
  });

  final ValueListenable<int> now;
  final FocusSession session;
  final FocusStrings strings;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isBreak = session.phase == 'break';
    final accent = isBreak ? scheme.tertiary : scheme.primary;
    return ValueListenableBuilder<int>(
      valueListenable: now,
      builder: (context, nowMs, _) {
        final target = session.targetEndUtc;
        final isStopwatch = target == null;
        final elapsedMs = math.max(0, nowMs - session.startUtc);
        final remainingMs = isStopwatch ? 0 : target - nowMs;
        final display = isStopwatch
            ? _formatElapsed(elapsedMs)
            : formatFocusCountdown(remainingMs);
        final progress = _goalProgress(
          isStopwatch: isStopwatch,
          elapsedMs: elapsedMs,
          target: target,
          startUtc: session.startUtc,
        );
        final semantics = isStopwatch
            ? strings.elapsedSemantics(display)
            : strings.remainingSemantics(display);
        final digits = RepaintBoundary(
          child: Text(
            display,
            maxLines: 1,
            style: DsType.numeric(
              theme.textTheme.displayLarge!.copyWith(
                fontSize: size * 0.235,
                fontWeight: FontWeight.w500,
                height: 1,
                color: scheme.onSurface,
              ),
            ),
          ),
        );
        return Semantics(
          container: true,
          label: semantics,
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: size,
              child: CustomPaint(
                // Ticks must paint AFTER the ring: the ring stroke sits at
                // radius 110-116 and otherwise covers the tick band at
                // 106-114. As a foreground painter the dial stays visible.
                foregroundPainter: _ClockDialPainter(
                  tickColor: scheme.outlineVariant.withValues(alpha: 0.7),
                  majorTickColor: scheme.onSurfaceVariant.withValues(
                    alpha: 0.55,
                  ),
                ),
                child: AppProgressRing(
                  value: progress,
                  size: size,
                  strokeWidth: 6,
                  color: accent,
                  semanticsLabel: semantics,
                  child: SizedBox(
                    width: size - 52,
                    child: FittedBox(fit: BoxFit.scaleDown, child: digits),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

double _goalProgress({
  required bool isStopwatch,
  required int elapsedMs,
  required int? target,
  required int startUtc,
}) {
  if (isStopwatch) {
    const cycleMs = 60 * msPerMinute;
    if (elapsedMs <= 0) return 0.0;
    final inCycle = elapsedMs % cycleMs;
    // At exact hour boundaries show a full ring, then restart the cycle.
    return inCycle == 0 ? 1.0 : inCycle / cycleMs;
  }
  if (target == null) return 0.0;
  final totalMs = target - startUtc;
  // A non-positive duration means the target is at or before the start, so
  // the goal is already reached: show a full ring instead of an empty one.
  if (totalMs <= 0) return 1.0;
  return (elapsedMs / totalMs).clamp(0.0, 1.0).toDouble();
}

class _ClockDialPainter extends CustomPainter {
  const _ClockDialPainter({
    required this.tickColor,
    required this.majorTickColor,
  });

  final Color tickColor;
  final Color majorTickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final outer = radius - 2;
    const tickCount = 60;
    for (var i = 0; i < tickCount; i++) {
      final isMajor = i % 5 == 0;
      final len = isMajor ? 8.0 : 4.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isMajor ? 1.6 : 1.0
        ..strokeCap = StrokeCap.round
        ..color = isMajor ? majorTickColor : tickColor;
      final angle = (2 * math.pi * i / tickCount) - math.pi / 2;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final p1 = Offset(
        center.dx + cosA * (outer - len),
        center.dy + sinA * (outer - len),
      );
      final p2 = Offset(center.dx + cosA * outer, center.dy + sinA * outer);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ClockDialPainter oldDelegate) =>
      oldDelegate.tickColor != tickColor ||
      oldDelegate.majorTickColor != majorTickColor;
}

/// Isolated elapsed label so the rest of the running view stays static.
class FocusElapsedLabel extends StatelessWidget {
  const FocusElapsedLabel({
    super.key,
    required this.now,
    required this.session,
    required this.strings,
  });

  final ValueListenable<int> now;
  final FocusSession session;
  final FocusStrings strings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: now,
      builder: (context, nowMs, _) {
        final minutes = ((nowMs - session.startUtc) / msPerMinute).floor();
        return Text(
          strings.elapsedLine(_phaseLabel(context, session.phase), minutes),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DsSpace.x4),
        Text(
          value,
          style: DsType.numeric(
            theme.textTheme.titleLarge!.copyWith(color: scheme.onSurface),
          ),
        ),
      ],
    );
  }
}

class _PausedBanner extends StatelessWidget {
  const _PausedBanner({
    required this.segment,
    required this.strings,
    required this.onResume,
    required this.onDiscard,
  });

  final PausedFocusSegment segment;
  final FocusStrings strings;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = segment.isStopwatch
        ? strings.modeStopwatch
        : formatFocusCountdown(segment.remainingMs ?? 0);
    return Semantics(
      container: true,
      label: strings.pausedSemantics,
      child: AppSurface(
        tonal: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.pausedTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DsSpace.x4),
            Text(
              strings.pausedLeft(remaining),
              style: DsType.numeric(
                theme.textTheme.headlineSmall!.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: DsSpace.x12),
            Wrap(
              spacing: DsSpace.x8,
              runSpacing: DsSpace.x8,
              children: [
                AppButton(
                  label: strings.resume,
                  icon: Icons.play_arrow,
                  onPressed: onResume,
                ),
                AppButton(
                  label: strings.discardPause,
                  variant: AppButtonVariant.ghost,
                  onPressed: onDiscard,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedHabitProgress extends StatelessWidget {
  const _LinkedHabitProgress({
    required this.habit,
    required this.loggedAmount,
    required this.session,
    required this.now,
  });

  final Habit habit;
  final double loggedAmount;
  final FocusSession session;
  final ValueListenable<int> now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goal = habit.goalAmount ?? 0;
    return ValueListenableBuilder<int>(
      valueListenable: now,
      builder: (context, nowMs, _) {
        final todayKey = habitDateKey(DateTime.now());
        final amount = liveHabitAmount(
          habitId: habit.id,
          selectedDayKey: todayKey,
          todayKey: todayKey,
          unit: habit.unit,
          loggedAmount: loggedAmount,
          sessionHabitId: session.habitId,
          sessionPhase: session.phase,
          sessionStartUtcMs: session.startUtc,
          nowMs: nowMs,
        );
        final percent = formatHabitPercent(amount: amount, goal: goal);
        return AppSurface(
          child: Row(
            children: [
              AppProgressRing(
                value: (amount / goal).clamp(0.0, 1.0),
                size: 48,
                child: Text(
                  percent,
                  style: DsType.numeric(theme.textTheme.labelSmall!),
                ),
              ),
              const SizedBox(width: DsSpace.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      formatHabitExact(
                        unit: habit.unit,
                        amount: amount,
                        goal: goal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
