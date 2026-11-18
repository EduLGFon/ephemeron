part of '../settings_screen.dart';

/// Flat grouped container. Rows inside keep their own 48dp touch targets.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).colorScheme.outlineVariant;
    return AppSurface(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.x4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: DsSpace.x16,
                endIndent: DsSpace.x16,
                color: dividerColor,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x16,
        vertical: DsSpace.x12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: DsIcon.md, color: scheme.onSurfaceVariant),
            const SizedBox(width: DsSpace.x12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: DsSpace.x4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: DsSpace.x8),
            trailing!,
          ] else if (onTap != null) ...<Widget>[
            const SizedBox(width: DsSpace.x8),
            Icon(
              Icons.chevron_right,
              size: DsIcon.md,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: content,
      );
    }
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: content,
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.switchKey,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: Switch(key: switchKey, value: value, onChanged: onChanged),
    );
  }
}

void _sectionGap(List<Widget> sections) =>
    sections.add(const SizedBox(height: DsSpace.x16));
