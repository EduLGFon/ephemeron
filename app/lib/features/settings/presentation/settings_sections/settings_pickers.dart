part of '../settings_screen.dart';

class _SettingsPickerRow<T> extends StatelessWidget {
  const _SettingsPickerRow({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.help,
  });

  final String title;
  final String? help;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x16,
        vertical: DsSpace.x12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (help != null) ...<Widget>[
            const SizedBox(height: DsSpace.x4),
            Text(
              help!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: DsSpace.x8),
          DropdownButton<T>(
            value: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(DsRadius.r12),
            items: items,
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

/// Inline advisory banner used for denied permissions and platform limits.
class _SettingsNotice extends StatelessWidget {
  const _SettingsNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.emphasis = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = emphasis ? scheme.error : scheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x16,
        vertical: DsSpace.x12,
      ),
      child: Container(
        padding: const EdgeInsets.all(DsSpace.x12),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(DsRadius.r12),
          border: Border.all(color: tint.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: DsIcon.md, color: tint),
            const SizedBox(width: DsSpace.x8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: DsSpace.x4),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (actionLabel != null || secondaryLabel != null) ...[
                    const SizedBox(height: DsSpace.x8),
                    Wrap(
                      spacing: DsSpace.x8,
                      runSpacing: DsSpace.x8,
                      children: <Widget>[
                        if (actionLabel != null && onAction != null)
                          AppButton(
                            label: actionLabel!,
                            onPressed: onAction,
                            variant: AppButtonVariant.secondary,
                          ),
                        if (secondaryLabel != null && onSecondary != null)
                          AppButton(
                            label: secondaryLabel!,
                            onPressed: onSecondary,
                            variant: AppButtonVariant.ghost,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
