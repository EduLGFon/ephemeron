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

  /// Side-by-side rows below this width leave too little room for the label.
  static const double _minSideBySideWidth = 240;

  /// Body text at 1.5x or larger pushes trailing controls onto their own line.
  static const double _stackTrailingTextSize = 24;

  /// Wide trailing controls never take more than half of the row, so the text
  /// column keeps a readable share and the row cannot overflow.
  static const double _trailingWidthFraction = 0.5;

  bool _stackTrailing(BuildContext context, double width) {
    if (trailing == null) return false;
    final scaledBody = MediaQuery.textScalerOf(context).scale(16);
    return width < _minSideBySideWidth || scaledBody >= _stackTrailingTextSize;
  }

  Widget _textColumn(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpace.x16,
        vertical: DsSpace.x12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leading = icon == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(end: DsSpace.x12),
                  child: Icon(
                    icon,
                    size: DsIcon.md,
                    color: scheme.onSurfaceVariant,
                  ),
                );
          if (_stackTrailing(context, constraints.maxWidth)) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    ?leading,
                    Expanded(child: _textColumn(context)),
                  ],
                ),
                const SizedBox(height: DsSpace.x8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * _trailingWidthFraction,
                    ),
                    child: trailing!,
                  ),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ?leading,
              Expanded(child: _textColumn(context)),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: DsSpace.x8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * _trailingWidthFraction,
                  ),
                  child: trailing!,
                ),
              ] else if (onTap != null) ...<Widget>[
                const SizedBox(width: DsSpace.x8),
                Icon(
                  Icons.chevron_right,
                  size: DsIcon.md,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ],
          );
        },
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
