// Part of the focus screen library: the one-per-second countdown face.
part of 'focus_screen.dart';

/// Big tabular digits inside a progress ring. Only this subtree listens to the
/// one-second ticker; the surrounding page does not rebuild.
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
        final elapsedMs = nowMs - session.startUtc;
        final remainingMs = isStopwatch ? 0 : target - nowMs;
        final display = isStopwatch
            ? _formatElapsed(elapsedMs)
            : formatFocusCountdown(remainingMs);
        final totalMs = isStopwatch ? 0 : target - session.startUtc;
        final progress = isStopwatch || totalMs <= 0
            ? 0.0
            : (elapsedMs / totalMs).clamp(0.0, 1.0).toDouble();
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
              child: AppProgressRing(
                value: progress,
                size: size,
                strokeWidth: 6,
                color: accent,
                semanticsLabel: semantics,
                child: SizedBox(
                  width: size - 48,
                  child: FittedBox(fit: BoxFit.scaleDown, child: digits),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
