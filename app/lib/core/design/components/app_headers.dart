// Page and section headings. Headers switch to a stacked action row on narrow
// screens so large text scales cannot force a horizontal overflow.
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import '../typography.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.padding = const EdgeInsets.fromLTRB(
      DsSpace.x16,
      DsSpace.x12,
      DsSpace.x16,
      DsSpace.x8,
    ),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DefaultTextStyle.merge(
          style: theme.textTheme.headlineSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          child: title,
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: DsSpace.x4),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            child: subtitle!,
          ),
        ],
      ],
    );
    final leadingWidget = leading;

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 420;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (leadingWidget != null) ...<Widget>[
                      leadingWidget,
                      const SizedBox(width: DsSpace.x12),
                    ],
                    Expanded(child: titleBlock),
                  ],
                ),
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: DsSpace.x8),
                  Wrap(
                    spacing: DsSpace.x4,
                    runSpacing: DsSpace.x4,
                    children: actions,
                  ),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (leadingWidget != null) ...<Widget>[
                leadingWidget,
                const SizedBox(width: DsSpace.x12),
              ],
              Expanded(child: titleBlock),
              if (actions.isNotEmpty) ...<Widget>[
                const SizedBox(width: DsSpace.x8),
                Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ],
          );
        },
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.count,
    this.action,
    this.description,
  });

  final String title;
  final int? count;
  final Widget? action;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final heading = Row(
      children: <Widget>[
        Flexible(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (count != null) ...<Widget>[
          const SizedBox(width: DsSpace.x8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpace.x8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(DsRadius.pill),
            ),
            child: Text(
              '$count',
              style: DsType.numeric(
                (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
        if (action != null) ...<Widget>[
          const SizedBox(width: DsSpace.x8),
          action!,
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.x8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          heading,
          if (description != null) ...<Widget>[
            const SizedBox(height: DsSpace.x4),
            Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
