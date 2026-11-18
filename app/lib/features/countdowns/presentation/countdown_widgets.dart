// Presentational countdown cells shared by the grouped grid. They take display
// values and callbacks only so the grouping/date logic stays in the screen.
import 'package:material_ui/material_ui.dart';

import '../../../core/design/components/app_surface.dart';
import '../../../core/design/components/rows.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import 'countdowns_strings.dart';

/// Height reserved for one grid cell. Scales with the user's text size so the
/// vertical card layout cannot overflow at 200%.
double countdownCardExtent(BuildContext context, {required bool noDate}) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  final base = noDate ? 88.0 : 128.0;
  return base * scale.clamp(1.0, 2.0);
}

enum CountdownAction { edit, delete }

class CountdownCardCell extends StatelessWidget {
  const CountdownCardCell({
    super.key,
    required this.title,
    required this.strings,
    this.days,
    this.dateLabel,
    this.compact = true,
    this.yearly = false,
    this.onTap,
    this.onAction,
  });

  final String title;
  final CountdownsStrings strings;
  final int? days;
  final String? dateLabel;
  final bool compact;
  final bool yearly;
  final VoidCallback? onTap;
  final ValueChanged<CountdownAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final menu = onAction == null
        ? null
        : PopupMenuButton<CountdownAction>(
            tooltip: strings.moreOptions,
            icon: const Icon(Icons.more_vert),
            onSelected: onAction,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: CountdownAction.edit,
                child: Text(strings.edit),
              ),
              PopupMenuItem(
                value: CountdownAction.delete,
                child: Text(strings.delete),
              ),
            ],
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _card(context)),
        ?menu,
      ],
    );
  }

  Widget _card(BuildContext context) {
    final value = days;
    if (value == null) return _NoDateCard(title: title, onTap: onTap);
    return AppCountdownCard(
      title: title,
      days: value,
      dateLabel: dateLabel,
      compact: compact,
      yearly: yearly,
      onTap: onTap,
    );
  }
}

class _NoDateCard extends StatelessWidget {
  const _NoDateCard({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = CountdownsStrings.of(context);
    return AppSurface(
      onTap: onTap,
      semanticLabel: '$title, ${strings.noDateLabel}',
      child: Row(
        children: [
          Text(
            '-',
            style: DsType.numeric(
              theme.textTheme.displaySmall!.copyWith(
                color: scheme.onSurfaceVariant,
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
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  strings.noDateLabel,
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
  }
}
