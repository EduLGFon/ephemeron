// Part of the focus screen library: shared formatting, habit credit, week
// summary and session history rows.
part of 'focus_screen.dart';

/// Remaining time captured when a timed session is paused. The current segment
/// is finished and a resume starts a fresh session with this remainder.
class PausedFocusSegment {
  const PausedFocusSegment({
    required this.remainingMs,
    required this.phase,
    this.taskId,
    this.habitId,
    this.alarmPreset,
    this.note,
  });

  /// Null for a paused stopwatch, which has no target end.
  final int? remainingMs;
  final String phase;
  final String? taskId;
  final String? habitId;
  final String? alarmPreset;
  final String? note;

  bool get isStopwatch => remainingMs == null;

  int get remainingMinutes =>
      ((remainingMs ?? 0) / msPerMinute).ceil().clamp(1, 24 * 60).toInt();
}

String formatFocusCountdown(int ms) {
  final negative = ms < 0;
  final absMs = negative ? -ms : ms;
  final totalSec = absMs ~/ 1000;
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final sec = totalSec % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = sec.toString().padLeft(2, '0');
  final body = h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  return negative ? '-$body' : body;
}

String _formatElapsed(int elapsedMs) {
  final totalSec = (elapsedMs < 0 ? 0 : elapsedMs) ~/ 1000;
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
}

String _phaseLabel(BuildContext context, String? phase) {
  final strings = FocusStrings.of(context);
  return switch (phase) {
    'break' => strings.modeBreak,
    'stopwatch' => strings.modeStopwatch,
    _ => strings.modeFocus,
  };
}

Future<void> _creditHabit(
  BuildContext context,
  WidgetRef ref,
  String habitId,
  int kept,
) async {
  final strings = FocusStrings.of(context);
  final repo = ref.read(habitRepositoryProvider);
  final container = ProviderScope.containerOf(context, listen: false);
  final today = habitDateKey(DateTime.now());
  final habit = await repo.habitById(habitId);
  final goal = habit?.goalAmount ?? 0;
  final previous = await repo.logFor(habitId, today);
  final minuteGoal = habit != null && isMinuteUnit(habit.unit) && goal > 0;
  if (minuteGoal) {
    await repo.addAmount(habitId, today, kept.toDouble());
  } else {
    await repo.logDone(habitId, today);
  }
  ref.invalidate(habitStreakProvider(habitId));
  if (!context.mounted) return;
  showUndoSnackBar(
    context,
    strings.creditHabit(kept),
    onUndo: () async {
      await repo.backfill(
        habitId,
        today,
        previous?.amount ?? 0,
        previous?.done ?? false,
      );
      if (previous?.skipped == true) {
        await repo.setSkipped(habitId, today, true);
      }
      // Undo can run after the running view unmounted, so use the long-lived
      // container captured while the context was valid.
      container.invalidate(habitStreakProvider(habitId));
    },
  );
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  final List<int> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = days.fold<int>(1, (a, b) => b > a ? b : a);
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 48 * (days[i] / max),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(DsRadius.r8),
                      ),
                    ),
                    const SizedBox(height: DsSpace.x4),
                    Text(
                      '${days[i]}',
                      style: DsType.numeric(
                        Theme.of(context).textTheme.labelSmall!,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = DateTime.fromMillisecondsSinceEpoch(session.startUtc)
        .toLocal();
    final end = session.endUtc == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(session.endUtc!).toLocal();
    final minutes = end == null
        ? null
        : ((session.endUtc! - session.startUtc) / msPerMinute).floor();
    final time = DeviceDateFormat.time(context, start);
    final parts = <String>[_phaseLabel(context, session.phase), time];
    if (minutes != null) {
      parts.add(FocusStrings.of(context).duration(minutes));
    }
    return AppSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x12,
        vertical: DsSpace.x8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  parts.join(' · '),
                  style: DsType.numeric(theme.textTheme.bodyMedium!),
                ),
                if (session.note != null && session.note!.isNotEmpty)
                  Text(
                    session.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (minutes == null)
            Text(
              _phaseLabel(context, session.phase),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _FocusHistorySection extends ConsumerWidget {
  const _FocusHistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = FocusStrings.of(context);
    final theme = Theme.of(context);
    final todayAsync = ref.watch(focusTodayMinutesProvider);
    final breakTodayAsync = ref.watch(breakTodayMinutesProvider);
    final weekAsync = ref.watch(focusWeekMinutesProvider);
    final recentAsync = ref.watch(recentFocusSessionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurface(
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  label: strings.todayFocus,
                  value: todayAsync.maybeWhen(
                    data: strings.duration,
                    orElse: () => strings.noValue,
                  ),
                ),
              ),
              const SizedBox(width: DsSpace.x16),
              Expanded(
                child: _Metric(
                  label: strings.todayBreak,
                  value: breakTodayAsync.maybeWhen(
                    data: strings.duration,
                    orElse: () => strings.noValue,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DsSpace.x16),
        SectionTitle(title: strings.weekTitle),
        weekAsync.maybeWhen(
          data: (days) => AppSurface(child: _WeekBars(days: days)),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: DsSpace.x16),
        SectionTitle(title: strings.recentTitle),
        recentAsync.maybeWhen(
          data: (sessions) => sessions.isEmpty
              ? Text(
                  strings.noSessions,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: [
                    for (final session in sessions.take(10)) ...[
                      _SessionTile(session: session),
                      const SizedBox(height: DsSpace.x8),
                    ],
                  ],
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
