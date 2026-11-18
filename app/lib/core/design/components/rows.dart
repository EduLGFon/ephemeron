// Presentational rows and cards for tasks, events, habits and countdowns.
// They take display values and callbacks only, so features format their own
// data and these widgets stay free of repositories and navigation.
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import '../typography.dart';
import 'visuals.dart';

class AppTaskRow extends StatelessWidget {
  const AppTaskRow({
    super.key,
    required this.title,
    this.subtitle,
    this.listColor,
    this.priority = 0,
    this.completed = false,
    this.overdue = false,
    this.dense = false,
    this.onTap,
    this.onToggle,
    this.trailing,
    this.leading,
    this.semanticsLabel,
  });

  final String title;
  final String? subtitle;
  final Color? listColor;
  final int priority;
  final bool completed;
  final bool overdue;
  final bool dense;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final Widget? trailing;
  final Widget? leading;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final level = priority.clamp(0, 4).toInt();
    final titleStyle = (dense ? text.bodyMedium : text.titleMedium)?.copyWith(
      color: completed ? scheme.onSurfaceVariant : scheme.onSurface,
      decoration: completed ? TextDecoration.lineThrough : null,
      decorationColor: scheme.onSurfaceVariant,
    );
    final parts = <String>[title];
    if (subtitle != null) parts.add(subtitle!);
    if (level > 0) parts.add('P$level');
    if (overdue) parts.add('Overdue');
    if (completed) parts.add('Completed');

    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          _TaskCheckbox(completed: completed, onToggle: onToggle, dense: dense),
          Expanded(
            child: Semantics(
              container: true,
              button: onTap != null,
              checked: completed,
              label: semanticsLabel ?? parts.join(', '),
              onTap: onTap,
              child: InkWell(
                onTap: onTap,
                excludeFromSemantics: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: DsSpace.x48),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      DsSpace.x4,
                      dense ? DsSpace.x8 : DsSpace.x12,
                      DsSpace.x12,
                      dense ? DsSpace.x8 : DsSpace.x12,
                    ),
                    child: ExcludeSemantics(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: DsSpace.x12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (listColor != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: DsSpace.x8,
                                        ),
                                        child: _Dot(color: listColor!),
                                      ),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: titleStyle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (subtitle != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      subtitle!,
                                      style: text.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (level > 0 || overdue)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: DsSpace.x4,
                                    ),
                                    child: Wrap(
                                      spacing: DsSpace.x12,
                                      runSpacing: DsSpace.x4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (level > 0)
                                          _PriorityMark(
                                            level: level,
                                            dense: dense,
                                          ),
                                        if (overdue)
                                          _MetaLabel(
                                            icon: Icons.warning_amber_rounded,
                                            label: 'Overdue',
                                            color: scheme.error,
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.x4),
              child: trailing,
            ),
        ],
      ),
    );
  }
}

class _TaskCheckbox extends StatelessWidget {
  const _TaskCheckbox({
    required this.completed,
    required this.onToggle,
    required this.dense,
  });

  final bool completed;
  final VoidCallback? onToggle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      checked: completed,
      button: onToggle != null,
      label: completed ? 'Mark incomplete' : 'Mark complete',
      onTap: onToggle,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: DsSpace.x48,
          child: Center(
            child: InkResponse(
              onTap: onToggle,
              excludeFromSemantics: true,
              radius: DsSpace.x16,
              child: Container(
                width: dense ? 20 : 22,
                height: dense ? 20 : 22,
                decoration: BoxDecoration(
                  color: completed ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(DsRadius.r8),
                  border: Border.all(
                    color: completed ? scheme.primary : scheme.outline,
                    width: 1.5,
                  ),
                ),
                child: AppCheckmark(
                  checked: completed,
                  size: dense ? 14 : 16,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppEventRow extends StatelessWidget {
  const AppEventRow({
    super.key,
    required this.title,
    required this.timeLabel,
    this.color,
    this.location,
    this.dense = false,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String timeLabel;
  final Color? color;
  final String? location;
  final bool dense;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final timeWidth = (dense ? 52.0 : 60.0) * scale.clamp(1.0, 2.0);
    final parts = <String>[timeLabel, title];
    if (location != null) parts.add(location!);

    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              button: onTap != null,
              label: parts.join(', '),
              onTap: onTap,
              child: InkWell(
                onTap: onTap,
                excludeFromSemantics: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: DsSpace.x48),
                  child: Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: DsSpace.x12,
                      vertical: dense ? DsSpace.x8 : DsSpace.x12,
                    ),
                    child: ExcludeSemantics(
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: dense ? 28 : 36,
                            decoration: BoxDecoration(
                              color: color ?? scheme.primary,
                              borderRadius: BorderRadius.circular(
                                DsRadius.pill,
                              ),
                            ),
                          ),
                          const SizedBox(width: DsSpace.x12),
                          SizedBox(
                            width: timeWidth,
                            child: Text(
                              timeLabel,
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: DsType.numeric(
                                (dense ? text.labelSmall : text.labelMedium)!
                                    .copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                          const SizedBox(width: DsSpace.x12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      (dense
                                              ? text.bodyMedium
                                              : text.titleSmall)
                                          ?.copyWith(color: scheme.onSurface),
                                ),
                                if (location != null)
                                  Text(
                                    location!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.x8),
              child: trailing,
            ),
        ],
      ),
    );
  }
}

class AppHabitChip extends StatelessWidget {
  const AppHabitChip({
    super.key,
    required this.name,
    required this.progress,
    this.done = false,
    this.color,
    this.onTap,
    this.onLongPress,
    this.size = 56,
  });

  final String name;
  final double progress;
  final bool done;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    return Semantics(
      container: true,
      button: onTap != null || onLongPress != null,
      toggled: done,
      label: '$name, $pct%',
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DsRadius.r16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            excludeFromSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(DsSpace.x8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppProgressRing(
                    value: progress,
                    size: size,
                    strokeWidth: 4,
                    color: color,
                    child: AppCheckmark(
                      checked: done,
                      size: size * 0.32,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: DsSpace.x4),
                  SizedBox(
                    width: size * 2,
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppHabitRow extends StatelessWidget {
  const AppHabitRow({
    super.key,
    required this.name,
    required this.progress,
    this.done = false,
    this.color,
    this.streakLabel,
    this.weekDots = const <bool>[],
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  final String name;
  final double progress;
  final bool done;
  final Color? color;
  final String? streakLabel;
  final List<bool> weekDots;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    final parts = <String>[name, '$pct%'];
    if (streakLabel != null) parts.add(streakLabel!);
    final dots = weekDots.take(7).toList(growable: false);

    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              button: onTap != null || onLongPress != null,
              toggled: done,
              label: parts.join(', '),
              onTap: onTap,
              onLongPress: onLongPress,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                excludeFromSemantics: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: DsSpace.x48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpace.x12,
                      vertical: DsSpace.x8,
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: AppProgressRing(
                            value: progress,
                            size: 40,
                            strokeWidth: 3,
                            color: color,
                            child: done
                                ? Icon(
                                    Icons.check,
                                    size: DsIcon.sm,
                                    color: scheme.onSurface,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: DsSpace.x12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExcludeSemantics(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              if (subtitle != null)
                                ExcludeSemantics(
                                  child: Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              if (streakLabel != null || dots.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: DsSpace.x4,
                                  ),
                                  child: Wrap(
                                    spacing: DsSpace.x8,
                                    runSpacing: DsSpace.x4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (streakLabel != null)
                                        ExcludeSemantics(
                                          child: _MetaLabel(
                                            icon: Icons
                                                .local_fire_department_outlined,
                                            label: streakLabel!,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      if (dots.isNotEmpty)
                                        _WeekDots(
                                          dots: dots,
                                          color: color ?? scheme.primary,
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.x8),
              child: trailing,
            ),
        ],
      ),
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.dots, required this.color});

  final List<bool> dots;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final filled in dots)
          Semantics(
            container: true,
            checked: filled,
            child: ExcludeSemantics(
              child: Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: filled ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: filled ? null : Border.all(color: outline),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AppCountdownCard extends StatelessWidget {
  const AppCountdownCard({
    super.key,
    required this.title,
    required this.days,
    this.dateLabel,
    this.color,
    this.onTap,
    this.compact = false,
    this.yearly = false,
  });

  final String title;
  final int days;
  final String? dateLabel;
  final Color? color;
  final VoidCallback? onTap;
  final bool compact;
  final bool yearly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final accent = color ?? scheme.primary;
    final parts = <String>[title, '$days'];
    if (dateLabel != null) parts.add(dateLabel!);
    if (yearly) parts.add('Yearly');
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final horizontal = compact && scale <= 1.3;
    final numeral = DsType.numeric(
      (compact ? text.headlineMedium : text.displaySmall)!.copyWith(
        color: scheme.onSurface,
      ),
    );

    final titleLine = Row(
      children: [
        _Dot(color: accent),
        const SizedBox(width: DsSpace.x8),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (compact ? text.titleSmall : text.titleMedium)?.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ),
        if (yearly) ...[
          const SizedBox(width: DsSpace.x8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: _YearlyBadge(scheme: scheme, text: text),
          ),
        ],
      ],
    );

    final body = horizontal
        ? Row(
            children: [
              Text('$days', style: numeral, maxLines: 1),
              const SizedBox(width: DsSpace.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleLine,
                    if (dateLabel != null)
                      Text(
                        dateLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$days', style: numeral, maxLines: 1),
              const SizedBox(height: DsSpace.x4),
              titleLine,
              if (dateLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.x4),
                  child: Text(
                    dateLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          );

    return Semantics(
      container: true,
      button: onTap != null,
      label: parts.join(', '),
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DsRadius.r16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            child: Padding(
              padding: EdgeInsets.all(compact ? DsSpace.x12 : DsSpace.x16),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _YearlyBadge extends StatelessWidget {
  const _YearlyBadge({required this.scheme, required this.text});

  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.x8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DsRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_repeat, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: DsSpace.x4),
          Flexible(
            child: Text(
              'Yearly',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: DsSpace.x4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _PriorityMark extends StatelessWidget {
  const _PriorityMark({required this.level, required this.dense});

  final int level;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (level) {
      1 => scheme.error,
      2 => scheme.tertiary,
      3 => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: dense ? 12 : 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(DsRadius.pill),
          ),
        ),
        const SizedBox(width: DsSpace.x4),
        Text(
          'P$level',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
