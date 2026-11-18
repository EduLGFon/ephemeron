// Now/Next hero for Today: active focus session first, then the event in
// progress, then the next timed event. Only the relative label rebuilds each
// minute; focus digits tick once per second inside a RepaintBoundary.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/components/app_buttons.dart';
import '../../../../core/design/components/app_surface.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/time/device_date_format.dart';
import '../../../../core/ui/app_feedback.dart';
import '../../../../data/drift/app_database.dart';
import '../../../focus/application/focus_providers.dart';
import '../today_strings.dart';

class TodayHero extends ConsumerStatefulWidget {
  const TodayHero({
    super.key,
    required this.now,
    required this.minuteTick,
    required this.currentEvent,
    required this.nextEvent,
    required this.onOpenEvent,
    required this.onOpenFocus,
  });

  final DateTime now;
  final ValueListenable<DateTime> minuteTick;
  final OccurrenceCacheData? currentEvent;
  final OccurrenceCacheData? nextEvent;
  final ValueChanged<OccurrenceCacheData> onOpenEvent;
  final VoidCallback onOpenFocus;

  @override
  ConsumerState<TodayHero> createState() => _TodayHeroState();
}

class _FocusPause {
  const _FocusPause({
    required this.minutes,
    this.taskId,
    this.habitId,
    this.phase,
  });

  final int minutes;
  final String? taskId;
  final String? habitId;
  final String? phase;
}

class _TodayHeroState extends ConsumerState<TodayHero> {
  _FocusPause? _paused;

  Future<void> _pause(FocusSession session) async {
    final target = session.targetEndUtc;
    final remaining = target == null
        ? 1
        : ((target - DateTime.now().toUtc().millisecondsSinceEpoch) /
                  Duration.millisecondsPerMinute)
              .ceil()
              .clamp(1, 24 * 60)
              .toInt();
    final pause = _FocusPause(
      minutes: remaining,
      taskId: session.taskId,
      habitId: session.habitId,
      phase: session.phase,
    );
    try {
      await ref.read(focusRepositoryProvider).finishSession(session.id);
      if (!mounted) return;
      setState(() => _paused = pause);
      ref.invalidate(currentFocusSessionProvider);
      ref.invalidate(focusTodayMinutesProvider);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not pause focus.');
    }
  }

  Future<void> _resume() async {
    final paused = _paused;
    if (paused == null) return;
    try {
      await ref
          .read(focusRepositoryProvider)
          .startSession(
            taskId: paused.taskId,
            habitId: paused.habitId,
            durationMin: paused.minutes,
            phase: paused.phase == 'break' ? 'break' : 'focus',
          );
      if (!mounted) return;
      setState(() => _paused = null);
      ref.invalidate(currentFocusSessionProvider);
      ref.invalidate(focusTodayMinutesProvider);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not resume focus.');
    }
  }

  Future<void> _stop(FocusSession session) async {
    try {
      await ref.read(focusRepositoryProvider).finishSession(session.id);
      if (!mounted) return;
      setState(() => _paused = null);
      ref.invalidate(currentFocusSessionProvider);
      ref.invalidate(focusTodayMinutesProvider);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not stop focus.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = TodayStrings.of(context);
    final session = ref.watch(currentFocusSessionProvider).value;
    if (session != null) {
      return AppSurface(
        key: const ValueKey<String>('today-hero-focus'),
        onTap: widget.onOpenFocus,
        child: _focusBody(context, strings, session),
      );
    }
    final paused = _paused;
    if (paused != null) {
      return AppSurface(
        key: const ValueKey<String>('today-hero-paused'),
        onTap: widget.onOpenFocus,
        child: _pausedBody(context, strings, paused),
      );
    }
    final current = widget.currentEvent;
    if (current != null) {
      return AppSurface(
        key: const ValueKey<String>('today-hero-now'),
        onTap: () => widget.onOpenEvent(current),
        child: _eventBody(
          context,
          strings,
          label: strings.now,
          event: current,
          isCurrent: true,
        ),
      );
    }
    final next = widget.nextEvent;
    if (next != null) {
      return AppSurface(
        key: const ValueKey<String>('today-hero-next'),
        onTap: () => widget.onOpenEvent(next),
        child: _eventBody(
          context,
          strings,
          label: strings.next,
          event: next,
          isCurrent: false,
        ),
      );
    }
    return AppSurface(
      key: const ValueKey<String>('today-hero-empty'),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.wb_sunny_outlined,
            size: DsIcon.md,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: DsSpace.x12),
          Expanded(
            child: Text(
              strings.clearHero,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventBody(
    BuildContext context,
    TodayStrings strings, {
    required String label,
    required OccurrenceCacheData event,
    required bool isCurrent,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = DateTime.fromMillisecondsSinceEpoch(event.startUtc).toLocal();
    final end = DateTime.fromMillisecondsSinceEpoch(event.endUtc).toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: DsSpace.x8),
            Expanded(
              child: ValueListenableBuilder<DateTime>(
                valueListenable: widget.minuteTick,
                builder: (context, now, _) {
                  final delta = isCurrent
                      ? end.difference(now).inMinutes
                      : start.difference(now).inMinutes;
                  final text = isCurrent
                      ? strings.endsIn(delta < 1 ? 1 : delta)
                      : strings.inMinutes(delta < 1 ? 1 : delta);
                  return Text(
                    text,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsType.numeric(
                      theme.textTheme.labelMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.x8),
        Text(
          event.title ?? 'Event',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DsSpace.x4),
        Text(
          '${DeviceDateFormat.time(context, start)} - '
          '${DeviceDateFormat.time(context, end)}',
          style: DsType.numeric(
            theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _focusBody(
    BuildContext context,
    TodayStrings strings,
    FocusSession session,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timed = session.targetEndUtc != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              session.phase == 'break' ? 'BREAK' : 'FOCUS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.timer_outlined,
              size: DsIcon.sm,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: DsSpace.x8),
        RepaintBoundary(
          child: _FocusDigits(
            startUtc: session.startUtc,
            targetEndUtc: session.targetEndUtc,
            large: timed,
          ),
        ),
        const SizedBox(height: DsSpace.x12),
        Wrap(
          spacing: DsSpace.x8,
          runSpacing: DsSpace.x8,
          children: <Widget>[
            if (timed)
              AppButton(
                label: strings.focusPause,
                variant: AppButtonVariant.secondary,
                icon: Icons.pause,
                onPressed: () => _pause(session),
              ),
            AppButton(
              label: strings.focusStop,
              variant: AppButtonVariant.ghost,
              icon: Icons.stop,
              onPressed: () => _stop(session),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pausedBody(
    BuildContext context,
    TodayStrings strings,
    _FocusPause paused,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.pause_circle_outline,
              size: DsIcon.sm,
              color: scheme.primary,
            ),
            const SizedBox(width: DsSpace.x8),
            Text(
              strings.focusPaused,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.x8),
        Text(
          '${paused.minutes}:00',
          style: DsType.numeric(
            theme.textTheme.displaySmall!.copyWith(
              color: scheme.onSurface,
              fontFamily: DsType.fraunces,
            ),
          ),
        ),
        const SizedBox(height: DsSpace.x12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton(
            label: strings.focusResume,
            icon: Icons.play_arrow,
            onPressed: _resume,
          ),
        ),
      ],
    );
  }
}

class _FocusDigits extends StatefulWidget {
  const _FocusDigits({
    required this.startUtc,
    required this.targetEndUtc,
    required this.large,
  });

  final int startUtc;
  final int? targetEndUtc;
  final bool large;

  @override
  State<_FocusDigits> createState() => _FocusDigitsState();
}

class _FocusDigitsState extends State<_FocusDigits> {
  final ValueNotifier<String> _text = ValueNotifier<String>('00:00');
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _update();
    // Only a running focus hero owns a per-second timer.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _update() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final target = widget.targetEndUtc;
    final seconds = target == null
        ? ((now - widget.startUtc) / Duration.millisecondsPerSecond).floor()
        : ((target - now) / Duration.millisecondsPerSecond).ceil();
    _text.value = _format(seconds < 0 ? 0 : seconds);
  }

  String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: _text,
      builder: (context, text, _) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          style: DsType.numeric(
            (widget.large
                    ? theme.textTheme.displayMedium
                    : theme.textTheme.displaySmall)!
                .copyWith(
                  color: theme.colorScheme.onSurface,
                  fontFamily: DsType.fraunces,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
