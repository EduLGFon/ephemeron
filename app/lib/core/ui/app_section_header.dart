// Section title with an optional count badge, description, and trailing
// action. Marks itself as a semantics header so screen readers can jump
// between sections.
import 'package:material_ui/material_ui.dart';

import '../theme/theme_tokens.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(
    this.title, {
    super.key,
    this.count,
    this.trailing,
    this.description,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpace.lg,
      vertical: AppSpace.sm,
    ),
  });

  final String title;
  final int? count;
  final Widget? trailing;
  final String? description;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: AppSpace.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm,
                            vertical: AppSpace.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '$count',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpace.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
